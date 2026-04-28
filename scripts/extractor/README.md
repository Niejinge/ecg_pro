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

The extractor writes:

- `ecg_data_extracted.json`: full extraction result with pages and draft cases.
- `admin_import_payloads.json`: case payloads shaped for the admin case model.
- `extraction_summary.txt`: compact extraction summary.
- `pages/`: rendered page images.
- `images/`: embedded PDF images when available.

## OCR

Native text PDFs work without OCR. Scanned PDFs need a local Tesseract install for text recognition.
If Tesseract is not available, the extractor still renders pages and groups draft cases, then marks OCR as unavailable.
