#!/usr/bin/env python3
"""Build assets/data/official_books.json from verified Ministry sources.

Usage:
    python3 tool/generate_official_catalog.py \
        --sources /path/to/research_moe \
        --output assets/data/official_books.json

The `--sources` directory must contain the unmodified JSON/HTML files fetched
from the official Ministry e-library:

  * Books-sec-books.json
  * Performance_Assessments-books.json
  * EgyptianBaccalaureate_*.html

The script never guesses a PDF URL. Every download_url comes verbatim from a
Ministry data file or embedded info-card. Rows whose source metadata conflicts
with the link (wrong part, wrong language, duplicate URL, inconsistent grade
label) are kept but marked `manual_review` with an Arabic explanation.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import unicodedata
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

VERIFIED_AT = "2026-10-24"
SCHOOL_YEAR = "2026-2027"
METADATA_VERSION = "catalog-2026.10.24.1"
PUBLISHER = "وزارة التربية والتعليم والتعليم الفني"

GENERAL_PAGE = "https://ellibrary.moe.gov.eg/Books-sec/"
ASSESSMENT_PAGE = "https://ellibrary.moe.gov.eg/Performance_Assessments/"
BAC_PAGE = "https://ellibrary.moe.gov.eg/EgyptianBaccalaureate/"

GRADE_MAP = {
    "الصف الأول الثانوى": "sec1",
    "الصف الأول الثانوي": "sec1",
    "الصف الثانى الثانوى": "sec2",
    "الصف الثاني الثانوي": "sec2",
    "الصف الثالث الثانوى": "sec3",
    "الصف الثالث الثانوي": "sec3",
}
GRADE_LABEL = {
    "sec1": "الصف الأول الثانوي",
    "sec2": "الصف الثاني الثانوي",
    "sec3": "الصف الثالث الثانوي",
}

SUBJECT_SLUGS = {
    "اللغة العربية": "arabic",
    "اللغة الإنجليزية": "english",
    "اللغة الفرنسية": "french",
    "اللغة الألمانية": "german",
    "اللغة الإيطالية": "italian",
    "اللغة الإسبانية": "spanish",
    "اللغة الصينية": "chinese",
    "الرياضيات": "math",
    "الرياضيات البحتة": "pure-math",
    "الرياضيات العامة": "general-math",
    "الرياضيات التطبيقية": "applied-math",
    "تطبيقات الرياضيات": "applied-math",
    "العلوم المتكاملة": "integrated-science",
    "الكيمياء": "chemistry",
    "الفيزياء": "physics",
    "الأحياء": "biology",
    "الإحصاء": "statistics",
    "التاريخ": "history",
    "التاريخ الوطني": "history",
    "الجغرافيا السياسية": "political-geography",
    "جغرافيا التنمية": "development-geography",
    "الفلسفة والمنطق": "philosophy-logic",
    "علم النفس والاجتماع": "psychology-sociology",
    "علم النفس": "psychology",
    "التربية الدينية الإسلامية": "islamic-religion",
    "التربية الدينية المسيحية": "christian-religion",
    "التربية الوطنية": "national-education",
    "المواطنة وحقوق الإنسان": "citizenship",
    "البرمجة والذكاء الاصطناعي": "programming-ai",
    "تكنولوجيا المعلومات والاتصالات": "ict",
    "المحاسبة": "accounting",
    "إدارة الأعمال": "business-administration",
    "الثقافة المالية": "financial-literacy",
    "الكتب الرسمية": "official-books",
}

LANGUAGE_LABEL = {
    "ar": "العربية",
    "en": "الإنجليزية",
    "fr": "الفرنسية",
    "de": "الألمانية",
    "es": "الإسبانية",
    "it": "الإيطالية",
    "zh": "الصينية",
}

PATHWAYS = {
    "medicine_life_sciences": "الطب وعلوم الحياة",
    "engineering_computer_science": "الهندسة وعلوم الحاسب",
    "business": "الأعمال",
    "arts_humanities": "الآداب والفنون",
}

ALLOWED_HOSTS = {
    "elearnningcontent.blob.core.windows.net",
    "egyptianbaccalaureate.blob.core.windows.net",
}


def clean(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def normalize_subject(raw: str) -> str:
    text = clean(raw)
    text = re.sub(r"[ً-ْٰـ]", "", text)
    text = re.split(r"\s*[-–—]\s*", text)[0].strip()
    text = re.sub(r"\s+باللغة\s+.*$", "", text).strip()
    text = re.sub(r"\s+لغة\s+أجنبية.*$", "", text).strip()
    text = re.sub(r"\s+قديم$", "", text).strip()
    return text


def slug(value: str) -> str:
    text = unicodedata.normalize("NFKD", clean(value)).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    if text:
        return text
    return "subject-" + hashlib.sha1(value.encode("utf-8")).hexdigest()[:8]


def subject_slug(ref: str, subject: str) -> str:
    base = normalize_subject(subject)
    if base in SUBJECT_SLUGS:
        return SUBJECT_SLUGS[base]
    return slug(base or ref)


def detect_language(subject: str, url: str = "") -> str:
    text = f"{subject} {url}".lower()
    if any(token in subject for token in ("الإنجليزية", "الإنجليزية", "الانجليز", "English")):
        return "en"
    if any(token in subject for token in ("الفرنسية", "French", "Française")):
        return "fr"
    if any(token in subject for token in ("الألمانية", "الالمانية", "German", "Deutsch")):
        return "de"
    if any(token in subject for token in ("الإيطالية", "الايطالية", "Italian", "Italiano")):
        return "it"
    if any(token in subject for token in ("الإسبانية", "الاسبانية", "Spanish", "Español")):
        return "es"
    if any(token in subject for token in ("الصينية", "Chinese")):
        return "zh"
    # Do not infer a language from arbitrary filename substrings:
    # "Citizenship" contains "it". The Ministry labels the language in the
    # subject card or in the title; when it does not, Arabic is the safe default.
    return "ar"


def resource_kind(subject: str, row_type: str = "") -> str:
    text = f"{subject} {row_type}"
    if "كراسة التدريبات" in text or "Workbook" in text:
        return "workbook"
    if "القصة" in text or "Story" in text:
        return "story"
    if "تقييم" in text or "الأداءات" in text or "أداءات" in text:
        return "assessment"
    if "الثقافة المالية" in text:
        return "activity"
    return "student_book"


def part_label(title: str, url: str) -> str:
    text = f"{title} {url}".lower()
    if "القصة" in title or "story" in text:
        return "story"
    if "الجزء الأول" in title or "الجزء الاول" in title or "part1" in text:
        return "1"
    if "الجزء الثاني" in title or "الجزء الثانى" in title or "part2" in text:
        return "2"
    if "كراسة" in title or "workbook" in text:
        return "workbook"
    return ""


def make_id(prefix: str, *parts: str, url: str = "") -> str:
    digest = hashlib.sha1((url or "|".join(parts)).encode("utf-8")).hexdigest()[:8]
    stem = "-".join(p for p in parts if p)
    stem = re.sub(r"[^a-z0-9-]+", "-", stem.lower()).strip("-")
    return f"{prefix}-{stem}-{digest}"


def base_book(
    *,
    book_id: str,
    grade: str,
    subject: str,
    title_ar: str,
    system: str,
    page: str,
    url: str,
    kind: str,
    track: str = "",
    requirement: str = "not_specified",
    language: str = "ar",
    status: str = "available",
    note: str = "",
    part: str = "",
    component: str = "",
) -> dict:
    return {
        "id": book_id,
        "title_ar": title_ar,
        "title_en": "",
        "subject": subject,
        "subject_id": subject_slug("", subject),
        "grade": grade,
        "system": system,
        "track": track,
        "term": "term1",
        "school_year": SCHOOL_YEAR,
        "language": language,
        "edition": f"الطبعة الرسمية {SCHOOL_YEAR}",
        "publisher": PUBLISHER,
        "official_source_url": page,
        "download_url": url,
        "source_page": page,
        "status": status,
        "resource_kind": kind,
        "requirement": requirement,
        "metadata_version": METADATA_VERSION,
        "part": part,
        "component": component,
        "source_note": note,
    }


def general_books(source: Path) -> list[dict]:
    rows = json.loads((source / "Books-sec-books.json").read_text(encoding="utf-8"))
    seen_urls: dict[str, str] = {}
    out: list[dict] = []
    for row in rows:
        subject = clean(row.get("subject"))
        grade_raw = clean(row.get("grade"))
        grade = GRADE_MAP.get(grade_raw)
        url = clean(row.get("link"))
        if not grade or not url:
            continue
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
            continue
        language = detect_language(subject, url)
        kind = resource_kind(subject, clean(row.get("type")))
        base = normalize_subject(subject)
        part = part_label(subject, url)
        notes: list[str] = []
        status = "available"
        if grade_raw not in {"الصف الأول الثانوى", "الصف الثانى الثانوى", "الصف الثالث الثانوى"}:
            status = "manual_review"
            notes.append("صيغة اسم الصف في الفهرس الرسمي غير متسقة؛ محتاجة تأكيد قبل الاعتماد.")
        if url in seen_urls:
            status = "manual_review"
            notes.append(f"نفس رابط كتاب آخر ({seen_urls[url]}). الرابط مش هيتنزّل تلقائيًا.")
        else:
            seen_urls[url] = subject
        if grade == "sec3":
            notes.append("الفهرس الرسمي لا يحدد الشعبة؛ متحطّش كمادة إجبارية لكل الطلاب.")
        book_id = make_id("gen", grade, subject_slug("", subject), language, part or kind, url=url)
        title = f"{subject} — {GRADE_LABEL[grade]} (كتاب الطالب)"
        out.append(
            base_book(
                book_id=book_id,
                grade=grade,
                subject=subject,
                title_ar=title,
                system="general_secondary",
                page=GENERAL_PAGE,
                url=url,
                kind=kind,
                language=language,
                status=status,
                note=" ".join(notes),
                part=part,
                component="" if not part else part,
            )
        )
    return out


def assessments(source: Path) -> list[dict]:
    rows = json.loads(
        (source / "Performance_Assessments-books.json").read_text(encoding="utf-8")
    )
    seen_urls: dict[str, str] = {}
    out: list[dict] = []
    for row in rows:
        if clean(row.get("stage")) != "الثانوي العام":
            continue
        subject = clean(row.get("subject"))
        grade = GRADE_MAP.get(clean(row.get("grade")))
        url = clean(row.get("link"))
        if not grade or not url:
            continue
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
            continue
        kind = "assessment"
        language = detect_language(subject, url)
        type_label = clean(row.get("type")) or "تقييم"
        part = part_label(type_label, url)
        notes: list[str] = []
        status = "available"
        if url in seen_urls:
            status = "manual_review"
            notes.append(f"نفس رابط تقييم آخر ({seen_urls[url]}). محتاج مراجعة.")
        else:
            seen_urls[url] = subject
        book_id = make_id(
            "assess",
            grade,
            subject_slug("", subject),
            language,
            part or "assessment",
            url=url,
        )
        out.append(
            base_book(
                book_id=book_id,
                grade=grade,
                subject=subject,
                title_ar=f"{subject} — {GRADE_LABEL[grade]} ({type_label})",
                system="general_secondary",
                page=ASSESSMENT_PAGE,
                url=url,
                kind=kind,
                language=language,
                status=status,
                note=" ".join(notes),
                part=part,
                component=type_label,
            )
        )
    return out


# ---------------------------------------------------------------------------
# Baccalaureate pages: the Ministry embeds the cards as a JS array.
# ---------------------------------------------------------------------------

CARD_RE = re.compile(
    r"\{\s*title:\s*\"([^\"]*)\"\s*,\s*text:\s*\"([^\"]*)\"\s*,\s*link:\s*\"([^\"]*)\"",
    re.S,
)

BAC_CATEGORIES = [
    # filename stem, pathway, requirement, subject page, verified path
    (
        "EgyptianBaccalaureate_CoreSubjects_Arabic-index.html",
        "",
        "core",
        "اللغة العربية",
        f"{BAC_PAGE}CoreSubjects/Arabic/",
    ),
    (
        "EgyptianBaccalaureate_CoreSubjects_EgyptianHistory-index.html",
        "",
        "core",
        "التاريخ الوطني",
        f"{BAC_PAGE}CoreSubjects/EgyptianHistory/",
    ),
    (
        "EgyptianBaccalaureate_CoreSubjects_FirstForeignLanguage_english.html",
        "",
        "core",
        "اللغة الإنجليزية",
        f"{BAC_PAGE}CoreSubjects/FirstForeignLanguage/english/",
    ),
    (
        "EgyptianBaccalaureate_CoreSubjects_FirstForeignLanguage_french.html",
        "",
        "core",
        "اللغة الفرنسية",
        f"{BAC_PAGE}CoreSubjects/FirstForeignLanguage/french/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Medicine-LifeSciences_Mathematics.html",
        "medicine_life_sciences",
        "pathway",
        "الرياضيات",
        f"{BAC_PAGE}SpecializedSubjects/Medicine-LifeSciences/Mathematics/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Medicine-LifeSciences_Physics.html",
        "medicine_life_sciences",
        "pathway",
        "الفيزياء",
        f"{BAC_PAGE}SpecializedSubjects/Medicine-LifeSciences/Physics/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Engineering-ComputerScience_Chemistry.html",
        "engineering_computer_science",
        "pathway",
        "الكيمياء",
        f"{BAC_PAGE}SpecializedSubjects/Engineering-ComputerScience/Chemistry/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Engineering-ComputerScience_Programming-ArtificialIntelligence.html",
        "engineering_computer_science",
        "pathway",
        "البرمجة والذكاء الاصطناعي",
        f"{BAC_PAGE}SpecializedSubjects/Engineering-ComputerScience/Programming-ArtificialIntelligence/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Business_Accounting.html",
        "business",
        "pathway",
        "المحاسبة",
        f"{BAC_PAGE}SpecializedSubjects/Business/Accounting/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Business_BusinessAdministration.html",
        "business",
        "pathway",
        "إدارة الأعمال",
        f"{BAC_PAGE}SpecializedSubjects/Business/BusinessAdministration/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Arts-Humanities_Psychology.html",
        "arts_humanities",
        "pathway",
        "علم النفس",
        f"{BAC_PAGE}SpecializedSubjects/Arts-Humanities/Psychology/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Arts-Humanities_SecondForeignLanguages_english.html",
        "arts_humanities",
        "pathway",
        "اللغة الإنجليزية",
        f"{BAC_PAGE}SpecializedSubjects/Arts-Humanities/SecondForeignLanguages/english/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Arts-Humanities_SecondForeignLanguages_french.html",
        "arts_humanities",
        "pathway",
        "اللغة الفرنسية",
        f"{BAC_PAGE}SpecializedSubjects/Arts-Humanities/SecondForeignLanguages/french/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Arts-Humanities_SecondForeignLanguages_german.html",
        "arts_humanities",
        "pathway",
        "اللغة الألمانية",
        f"{BAC_PAGE}SpecializedSubjects/Arts-Humanities/SecondForeignLanguages/german/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Arts-Humanities_SecondForeignLanguages_italy.html",
        "arts_humanities",
        "pathway",
        "اللغة الإيطالية",
        f"{BAC_PAGE}SpecializedSubjects/Arts-Humanities/SecondForeignLanguages/italy/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Arts-Humanities_SecondForeignLanguages_spanish.html",
        "arts_humanities",
        "pathway",
        "اللغة الإسبانية",
        f"{BAC_PAGE}SpecializedSubjects/Arts-Humanities/SecondForeignLanguages/spanish/",
    ),
    (
        "EgyptianBaccalaureate_SpecializedSubjects_Arts-Humanities_SecondForeignLanguages_Chinese.html",
        "arts_humanities",
        "pathway",
        "اللغة الصينية",
        f"{BAC_PAGE}SpecializedSubjects/Arts-Humanities/SecondForeignLanguages/Chinese/",
    ),
    (
        "EgyptianBaccalaureate_Activities_FinancialLiteracy.html",
        "",
        "optional",
        "الثقافة المالية",
        f"{BAC_PAGE}Activities/FinancialLiteracy/",
    ),
]


def baccalaureate(source: Path) -> list[dict]:
    seen_urls: dict[str, str] = {}
    out: list[dict] = []
    for filename, pathway, requirement, page_subject, page_url in BAC_CATEGORIES:
        path = source / filename
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for raw_title, raw_text, raw_link in CARD_RE.findall(text):
            title = html.unescape(clean(raw_title))
            title = re.sub(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]\s*", "", title).strip()
            card_text = html.unescape(clean(raw_text))
            card_text = re.sub(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]\s*", "", card_text).strip()
            url = clean(raw_link)
            if not url:
                continue
            parsed = urlparse(url)
            if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
                continue
            language = detect_language(card_text or page_subject, url)
            part = part_label(title, url)
            notes: list[str] = []
            status = "available"

            lower_name = url.lower().rsplit("/", 1)[-1]
            # The official index currently links the English L2 part 2 card to
            # a Chinese PDF. Keep the row visible but never download it blindly.
            if "chinese" in lower_name and "صينية" not in card_text:
                status = "manual_review"
                notes.append("بيانات البطاقة الرسمية تربط كتابًا غير الكتاب المذكور؛ الرابط مش هيتنزّل تلقائيًا.")
            if "الجزء الأول" in title or "الجزء الاول" in title:
                if "part2" in lower_name or "part-2" in lower_name:
                    status = "manual_review"
                    notes.append("العنوان يقول الجزء الأول لكن رابط الملف للجزء الثاني؛ يحتاج تأكيد.")
            if "الجزء الثاني" in title or "الجزء الثانى" in title:
                if "part1" in lower_name or "part-1" in lower_name:
                    status = "manual_review"
                    notes.append("العنوان يقول الجزء الثاني لكن رابط الملف للجزء الأول؛ يحتاج تأكيد.")
            if url in seen_urls:
                status = "manual_review"
                notes.append(f"نفس رابط بطاقة أخرى ({seen_urls[url]}).")
            else:
                seen_urls[url] = card_text or title

            subject = normalize_subject(page_subject)
            full_subject = card_text.split("(")[0].strip() if card_text else page_subject
            if not full_subject:
                full_subject = page_subject
            book_id = make_id(
                "bac",
                "sec2",
                pathway or "core",
                subject_slug("", page_subject),
                language,
                part or "book",
                url=url,
            )
            title_ar = f"{full_subject} — {PATHWAYS.get(pathway, 'المواد الأساسية')} (الصف الثاني الثانوي، {title})"
            out.append(
                base_book(
                    book_id=book_id,
                    grade="sec2",
                    subject=full_subject,
                    title_ar=title_ar,
                    system="egyptian_baccalaureate",
                    page=page_url,
                    url=url,
                    kind=resource_kind(page_subject, title),
                    track=pathway,
                    requirement=requirement,
                    language=language,
                    status=status,
                    note=" ".join(notes),
                    part=part,
                    component=title,
                )
            )
    return out


def grade12_baccalaureate_notices() -> list[dict]:
    out = []
    for pathway, label in PATHWAYS.items():
        out.append(
            base_book(
                book_id=f"bac-sec3-{pathway.replace('_', '-')}-not-published",
                grade="sec3",
                subject="الكتب الرسمية",
                title_ar=(
                    "كتب الصف الثالث الثانوي — البكالوريا المصرية "
                    f"({label}) — لم تُنشر بعد"
                ),
                system="egyptian_baccalaureate",
                page=BAC_PAGE,
                url="",
                kind="notice",
                track=pathway,
                requirement="not_specified",
                status="not_published",
                note=(
                    "صفحة البكالوريا الرسمية المنشورة حاليًا تخص الصف الثاني فقط. "
                    "لا يوجد رابط رسمي للصف الثالث، والتطبيق لا يخترع رابطًا."
                ),
            )
        )
    return out


def source_rows() -> list[dict]:
    return [
        {
            "id": "general-secondary",
            "title": "المكتبة الإلكترونية — كتب الثانوي العام 2026–2027",
            "url": GENERAL_PAGE,
            "verified_at": VERIFIED_AT,
            "publisher": PUBLISHER,
            "notes": "books.json الرسمي، 96 بطاقة كتاب طالب للصفوف الثلاثة.",
        },
        {
            "id": "performance-assessments",
            "title": "المكتبة الإلكترونية — الأداءات والتقييمات 2026–2027",
            "url": ASSESSMENT_PAGE,
            "verified_at": VERIFIED_AT,
            "publisher": PUBLISHER,
            "notes": "تم تضمين تقييمات الثانوي العام فقط.",
        },
        {
            "id": "baccalaureate",
            "title": "البكالوريا المصرية — الصفحة الرسمية 2026–2027",
            "url": BAC_PAGE,
            "verified_at": VERIFIED_AT,
            "publisher": PUBLISHER,
            "notes": "الصفحة المنشورة حاليًا تغطي الصف الثاني الثانوي (Grade 11) فقط.",
        },
    ] + [
        {
            "id": "bac-" + slug(page_url.removeprefix(BAC_PAGE).replace("/", "-")),
            "title": page_subject,
            "url": page_url,
            "verified_at": VERIFIED_AT,
            "publisher": PUBLISHER,
            "notes": f"المسار/المادة: {PATHWAYS.get(pathway, 'المواد الأساسية')}.",
        }
        for filename, pathway, requirement, page_subject, page_url in BAC_CATEGORIES
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    books = general_books(args.sources) + assessments(args.sources)
    books += baccalaureate(args.sources)
    books += grade12_baccalaureate_notices()

    # Stable, readable order: grade, system, then Arabic title.
    books.sort(key=lambda b: (b["grade"], b["system"], b["title_ar"], b["download_url"]))

    ids = [b["id"] for b in books]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate catalog ids; refusing to write")

    payload = {
        "version": 2,
        "updated": VERIFIED_AT,
        "school_year": SCHOOL_YEAR,
        "notes": (
            "الفهرس مبني على صفحات وزارة التربية والتعليم الرسمية 2026–2027. "
            "الفهرس العام لا يحدد الشعب، فظهور الكتاب لا يعني أنه إجباري على كل طالب. "
            "كتب البكالوريا المنشورة تخص الصف الثاني فقط، والصف الثالث ممثل كـ not_published."
        ),
        "sources": source_rows(),
        "books": books,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {len(books)} books to {args.output}")
    print("systems:", {s: sum(1 for b in books if b["system"] == s) for s in {b["system"] for b in books}})
    print("statuses:", {s: sum(1 for b in books if b["status"] == s) for s in {b["status"] for b in books}})


if __name__ == "__main__":
    main()
