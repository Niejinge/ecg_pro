import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from extract_ecg_data import (  # noqa: E402
    detect_keywords,
    discover_tesseract_cmd,
    extract_key_leads,
    find_chapter_marker,
    group_into_cases,
    infer_diagnosis,
    infer_risk_level,
    normalize_ocr_text,
    should_ocr_page,
)
from import_extracted_cases import safe_slug as import_safe_slug  # noqa: E402
from import_extracted_cases import truncate_case_payload  # noqa: E402


class ExtractEcgDataTests(unittest.TestCase):
    def test_detect_keywords_and_risk_level(self):
        text = "心电图诊断：ST段抬高型心肌梗死，V2-V5 导联明显抬高。"

        keywords = detect_keywords(text)

        self.assertIn("ST段抬高", keywords)
        self.assertIn("心肌梗死", keywords)
        self.assertEqual(infer_risk_level(text, keywords), "critical")

    def test_infer_diagnosis_from_labeled_text(self):
        text = "病史：胸痛。\n诊断：室性心动过速\n处理：电复律。"

        self.assertEqual(infer_diagnosis(text, []), "室性心动过速")

    def test_extract_key_leads_avoids_substring_noise(self):
        self.assertEqual(
            extract_key_leads("V1、V2、II 导联异常，VIII 不是导联"),
            ["II", "V1", "V2"],
        )

    def test_discover_tesseract_cmd_accepts_explicit_path(self):
        fake_cmd = str(Path(__file__).resolve())

        self.assertEqual(discover_tesseract_cmd(fake_cmd), fake_cmd)

    def test_normalize_ocr_text_and_find_chapter_marker(self):
        text = "第 1 章\n心 电 图 基 本 知 识"
        normalized = normalize_ocr_text(text)

        self.assertIn("心电图基本知识", normalized)
        self.assertEqual(find_chapter_marker(normalized), "第 1 章 心电图基本知识")

    def test_group_into_cases_uses_markers_when_available(self):
        pages = [
            {
                "page_number": 1,
                "text": "病例1\n诊断：窦性心律",
                "case_marker": "病例1",
                "chapter_marker": None,
                "ecg_keywords": ["窦性心律"],
                "embedded_images": [],
                "page_image_path": "pages/page_0001.png",
            },
            {
                "page_number": 2,
                "text": "解析页",
                "case_marker": None,
                "chapter_marker": None,
                "ecg_keywords": [],
                "embedded_images": [],
                "page_image_path": "pages/page_0002.png",
            },
            {
                "page_number": 3,
                "text": "病例2\n诊断：房颤",
                "case_marker": "病例2",
                "chapter_marker": None,
                "ecg_keywords": ["房颤"],
                "embedded_images": [],
                "page_image_path": "pages/page_0003.png",
            },
        ]

        cases = group_into_cases(
            pages,
            case_page_span=2,
            grouping="auto",
            infer_non_case_diagnosis=False,
            case_prefix="TEST",
            source_book="book",
        )

        self.assertEqual([case["source_pages"] for case in cases], [[1, 2], [3]])
        self.assertEqual(cases[0]["case_code"], "TEST-0001")

    def test_chapter_records_do_not_infer_clinical_diagnosis(self):
        pages = [
            {
                "page_number": 1,
                "normalized_text": "第 1 章\n心脏节律\n室颤是一种危急心律失常。",
                "text": "第 1 章\n心脏节律\n室颤是一种危急心律失常。",
                "case_marker": None,
                "chapter_marker": "第 1 章 心脏节律",
                "ecg_keywords": ["室颤"],
                "embedded_images": [],
                "page_image_path": "pages/page_0001.png",
            }
        ]

        cases = group_into_cases(
            pages,
            case_page_span=2,
            grouping="chapter",
            infer_non_case_diagnosis=False,
            case_prefix="TEST",
            source_book="book",
        )

        self.assertEqual(cases[0]["diagnosis"], "待人工判读")
        self.assertEqual(cases[0]["risk_level"], "low")
        self.assertTrue(cases[0]["needs_manual_review"])

    def test_non_case_records_can_infer_when_enabled_for_test_imports(self):
        pages = [
            {
                "page_number": 1,
                "normalized_text": "室颤是一种危急心律失常。",
                "text": "室颤是一种危急心律失常。",
                "case_marker": None,
                "chapter_marker": None,
                "ecg_keywords": ["室颤"],
                "embedded_images": [],
                "page_image_path": "pages/page_0001.png",
            }
        ]

        cases = group_into_cases(
            pages,
            case_page_span=2,
            grouping="fixed",
            infer_non_case_diagnosis=True,
            case_prefix="TEST",
            source_book="book",
        )

        self.assertEqual(cases[0]["diagnosis"], "室颤")
        self.assertEqual(cases[0]["risk_level"], "critical")

    def test_import_safe_slug_handles_chinese_names(self):
        self.assertRegex(import_safe_slug("临床心电图精解", "book"), r"^book-[0-9a-f]{10}$")
        self.assertEqual(import_safe_slug("ECG Book 6", "book"), "ecg-book-6")

    def test_ocr_page_step_limits_ocr_to_sampled_pages(self):
        self.assertTrue(should_ocr_page("", "auto", page_number=1, ocr_page_step=4))
        self.assertFalse(should_ocr_page("", "auto", page_number=2, ocr_page_step=4))

    def test_import_payload_truncates_database_limited_fields(self):
        payload = truncate_case_payload(
            {
                "case_code": "X" * 40,
                "title": "T" * 300,
                "diagnosis": "D" * 300,
                "rhythm_type": "R" * 140,
                "heart_rate": "H" * 80,
            }
        )

        self.assertEqual(len(payload["case_code"]), 32)
        self.assertEqual(len(payload["title"]), 255)
        self.assertEqual(len(payload["diagnosis"]), 255)
        self.assertEqual(len(payload["rhythm_type"]), 128)
        self.assertEqual(len(payload["heart_rate"]), 64)


if __name__ == "__main__":
    unittest.main()
