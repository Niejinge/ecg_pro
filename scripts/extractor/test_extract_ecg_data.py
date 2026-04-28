import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from extract_ecg_data import (  # noqa: E402
    detect_keywords,
    extract_key_leads,
    group_into_cases,
    infer_diagnosis,
    infer_risk_level,
)


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
            case_prefix="TEST",
            source_book="book",
        )

        self.assertEqual([case["source_pages"] for case in cases], [[1, 2], [3]])
        self.assertEqual(cases[0]["case_code"], "TEST-0001")


if __name__ == "__main__":
    unittest.main()
