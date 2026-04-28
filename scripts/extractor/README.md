# ECG PDF Extractor

This folder contains local utilities for converting ECG PDF books into draft case data.

## Usage

```powershell
python scripts\extractor\extract_ecg_data.py `
  --pdf "D:\心电图学习\学习\25心电图电子书\轻松学习心电图  （第六版）.pdf" `
  --output-dir scripts\extractor\output\easy_ecg_6th_sample `
  --max-pages 8 `
  --ocr auto
```

For test imports from scanned textbooks without explicit case markers, use fixed grouping and allow rough keyword inference:

```powershell
python scripts\extractor\extract_ecg_data.py `
  --pdf "D:\path\book.pdf" `
  --output-dir scripts\extractor\output\book_import `
  --grouping fixed `
  --case-page-span 4 `
  --ocr-page-step 4 `
  --infer-non-case-diagnosis `
  --ocr auto
```

The extractor writes:

- `ecg_data_extracted.json`: full extraction result with pages and draft cases.
- `admin_import_payloads.json`: case payloads shaped for the admin case model.
- `extraction_summary.txt`: compact extraction summary.
- `pages/`: rendered page images.
- `images/`: embedded PDF images when available.

## OCR

Native text PDFs work without OCR. Scanned PDFs need a local Tesseract install for text recognition.
If Tesseract is not available, the extractor still renders pages and groups draft cases, then marks OCR as unavailable.

## Import to Local API

```powershell
python scripts\extractor\import_extracted_cases.py `
  scripts\extractor\output\some_book_extracted\ecg_data_extracted.json `
  --publish `
  --update-existing `
  --max-images-per-case 2
```

The importer creates one category per source book, adds a `PDF导入` tag plus OCR keyword tags, creates or updates cases by `case_code`, uploads rendered page images, and optionally publishes the records.
