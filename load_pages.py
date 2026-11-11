#Download the Wiki bird lists and store their sections, lines, and words in the staging tables

import re
import requests
from bs4 import BeautifulSoup

US_URL = "https://en.wikipedia.org/wiki/List_of_birds_of_the_United_States"
STATE_URL = "https://en.wikipedia.org/wiki/List_of_birds_of_{slug}"
HEADERS = {"User-Agent": "us-bird-checklist/1.0 (student data project)"}
US_PAGE_ID = 0  # state pages use their state_id (1-50)


def fetch(url):
    response = requests.get(url, headers=HEADERS, timeout=30)
    response.raise_for_status()
    return response.text


def extract_sections(html, with_paragraph):
    """One row per <h2> section: (section_idx, heading, first <p> text, first <ul> text)."""
    soup = BeautifulSoup(html, "html.parser")
    rows = []
    for idx, div in enumerate(soup.find_all("div", class_="mw-heading mw-heading2")):
        h2 = div.find("h2")
        p = div.find_next("p") if with_paragraph else None
        ul = div.find_next("ul")
        rows.append((idx,
                     h2.text if h2 else None,
                     p.text if p else None,
                     ul.text if ul else None))
    return rows


def split_page(page_id, html, with_paragraph):
    """Rows for the three staging tables (sections, list lines, and the words of each line)."""
    sections, lines, words = [], [], []
    for idx, heading, paragraph, list_text in extract_sections(html, with_paragraph):
        sections.append((page_id, idx, heading, paragraph))
        if list_text is None:
            continue
        for line_no, line in enumerate(list_text.strip().split("\n"), start=1):
            lines.append((page_id, idx, line_no, line))
            for word_no, match in enumerate(re.finditer(r"\S+", line), start=1):  # same words as line.split()
                words.append((page_id, idx, line_no, word_no, match.group(), match.start() + 1, match.end()))
    return sections, lines, words


def insert(con, page_rows):
    sections, lines, words = page_rows
    with con.cursor() as cursor:
        cursor.executemany("INSERT INTO stg_section VALUES (%s, %s, %s, %s)", sections)
        cursor.executemany("INSERT INTO stg_line VALUES (%s, %s, %s, %s)", lines)
        cursor.executemany("INSERT INTO stg_word VALUES (%s, %s, %s, %s, %s, %s, %s)", words)


def load(con, refresh=False):
    """Fill the staging tables, it skips the download if they already hold the pages."""
    with con.cursor() as cursor:
        cursor.execute("SELECT COUNT(*) FROM stg_section WHERE page_id = %s", (US_PAGE_ID,))
        already_loaded = cursor.fetchone()[0] > 0
        if already_loaded and not refresh:
            print("Pages already downloaded (use --refresh to download them again).")
            return
        for table in ("stg_word", "stg_line", "stg_section"):
            cursor.execute(f"DELETE FROM {table}")
        cursor.execute("SELECT state_id, wiki_slug FROM us_state ORDER BY state_id")
        states = cursor.fetchall()

    print("Downloading the U.S. list...")
    insert(con, split_page(US_PAGE_ID, fetch(US_URL), with_paragraph=True))
    for state_id, slug in states:
        print(f"Downloading {slug} ({state_id}/{len(states)})")
        insert(con, split_page(state_id, fetch(STATE_URL.format(slug=slug)), with_paragraph=False))
