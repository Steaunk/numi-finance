"""Bounded, isolated PDF text/OCR worker. Never executes document actions."""
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


def extract(path, inspect_only=False):
    import pypdfium2 as pdfium
    doc = pdfium.PdfDocument(path)
    count = len(doc)
    if not 1 <= count <= 20:
        raise ValueError('Use a PDF with 1–20 pages.')
    if inspect_only:
        return {'pages': count}
    pages, ocr_pages, missing = [], 0, 0
    deadline = time.monotonic() + 35
    for index in range(count):
        page = doc[index]
        textpage = page.get_textpage()
        text = textpage.get_text_range()
        textpage.close()
        if len(''.join(text.split())) < 30:
            if ocr_pages < 5 and shutil.which('tesseract') and time.monotonic() < deadline - 8:
                image = Path(path).with_name('ocr.png')
                bitmap = page.render(scale=min(2.2, 1800 / max(page.get_size())))
                bitmap.to_pil().save(image)
                bitmap.close()
                try:
                    result = subprocess.run(['tesseract', str(image), 'stdout', '-l', os.environ.get('TRAVEL_OCR_LANGUAGES', 'eng+chi_sim+jpn')],
                                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=7, check=True)
                    text = result.stdout.decode('utf-8', errors='replace')
                    ocr_pages += 1
                except (subprocess.SubprocessError, OSError):
                    missing += 1
                finally:
                    image.unlink(missing_ok=True)
            else:
                missing += 1
        pages.append(text[:15000])
        page.close()
    doc.close()
    raw = '\n\n'.join(pages)
    warning = 'OCR was used; check all dates, times and ticket numbers.' if ocr_pages else ''
    if missing:
        warning += ' Some scanned pages could not be read. Enter missing details from the original PDF.'
    if len(raw) > 15000:
        warning += ' Long document: only the first 15,000 characters are shown.'
    return {'text': raw[:15000], 'pages': count, 'ocr': bool(ocr_pages), 'warning': warning.strip()}


if __name__ == '__main__':
    try:
        import resource
        resource.setrlimit(resource.RLIMIT_CPU, (40, 40))
        resource.setrlimit(resource.RLIMIT_FSIZE, (32 * 1024 * 1024,) * 2)
        if sys.platform == 'linux':
            resource.setrlimit(resource.RLIMIT_AS, (768 * 1024 * 1024,) * 2)
        print(json.dumps(extract(sys.argv[1], '--inspect' in sys.argv)))
    except Exception:
        print(json.dumps({'error': 'Could not read this PDF. It may be damaged, password-protected or exceed 20 pages.'}))
        sys.exit(1)
