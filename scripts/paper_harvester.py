#!/usr/bin/env python3
"""
VetPaper Harvester — Academic Paper Parser for VetVoice RAG

Sources:
  1. Anna's Archive  — search + download PDFs by keywords
  2. PubMed / PMC    — NCBI E-utilities API for open-access papers
  3. Semantic Scholar — free API for metadata + abstracts

Pipeline:
  search → download PDFs → extract text → clean → chunk → merge → rebuild FAISS → upload to HF Hub

Usage:
  python paper_harvester.py --source annas --query "canine atopic dermatitis" --max 20
  python paper_harvester.py --source pubmed --query "feline dermatophytosis" --max 50
  python paper_harvester.py --source semantic --query "dog skin pyoderma" --max 30
  python paper_harvester.py --source all --query "veterinary dermatology" --max 20
  python paper_harvester.py --rebuild   # rebuild FAISS from all collected data
  python paper_harvester.py --local-dir /path/to/pdfs   # ingest local PDFs
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from urllib.parse import quote_plus

import requests

# ---------- logging ----------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("paper_harvester")

# ---------- constants ----------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
KNOWLEDGE_DIR = PROJECT_DIR / "knowledge_base"
PAPERS_DIR = PROJECT_DIR / "collected_papers"
METADATA_FILE = PAPERS_DIR / "papers_metadata.json"
HF_REPO = "shrayyyy/vet-derm-rag"
HF_TOKEN = os.environ.get("HF_TOKEN", "")

# Veterinary dermatology search queries for batch harvesting
VET_DERM_QUERIES = [
    # Canine
    "canine atopic dermatitis", "dog allergic skin disease",
    "canine pyoderma bacterial", "canine demodicosis",
    "canine Malassezia dermatitis", "dog food allergy dermatitis",
    "canine pemphigus foliaceus", "canine sebaceous adenitis",
    "canine hypothyroidism alopecia", "canine hyperadrenocorticism skin",
    "canine otitis externa treatment", "canine interdigital furunculosis",
    "canine acral lick dermatitis", "canine epitheliotropic lymphoma",
    "canine zinc-responsive dermatosis",
    # Feline
    "feline dermatophytosis ringworm", "feline eosinophilic granuloma",
    "feline atopic dermatitis", "feline acne treatment",
    "feline pemphigus", "feline psychogenic alopecia",
    # General
    "veterinary dermatology diagnosis", "dog skin biopsy interpretation",
    "canine pruritus diagnostic algorithm", "veterinary dermatology therapy",
    "immune-mediated skin disease dog", "cutaneous adverse drug reaction dog",
    "canine superficial bacterial folliculitis",
    "dermatophytosis treatment veterinary", "canine cutaneous histiocytoma",
    "veterinary dermatology immunotherapy",
]


# ============================================================
# PDF Text Extraction
# ============================================================

def extract_text_from_pdf(pdf_path: str) -> Optional[str]:
    """Extract text from a PDF file using PyMuPDF (fitz) or pdfplumber"""
    # Try PyMuPDF first (faster, better quality)
    try:
        import fitz  # PyMuPDF
        doc = fitz.open(pdf_path)
        text_parts = []
        for page_num, page in enumerate(doc):
            text = page.get_text("text")
            if text.strip():
                text_parts.append(text)
        doc.close()
        full_text = "\n\n".join(text_parts)
        if len(full_text.strip()) > 200:
            return full_text
    except ImportError:
        pass
    except Exception as e:
        log.warning(f"PyMuPDF failed for {pdf_path}: {e}")

    # Fallback to pdfplumber
    try:
        import pdfplumber
        text_parts = []
        with pdfplumber.open(pdf_path) as pdf:
            for page in pdf.pages:
                text = page.extract_text()
                if text and text.strip():
                    text_parts.append(text)
        full_text = "\n\n".join(text_parts)
        if len(full_text.strip()) > 200:
            return full_text
    except ImportError:
        log.error("Neither PyMuPDF nor pdfplumber installed. Run: pip install PyMuPDF pdfplumber")
        return None
    except Exception as e:
        log.warning(f"pdfplumber failed for {pdf_path}: {e}")

    return None


def clean_paper_text(text: str) -> str:
    """Clean extracted paper text: remove headers, footers, normalize"""
    # Remove page numbers (standalone)
    text = re.sub(r'\n\s*\d{1,4}\s*\n', '\n', text)
    # Remove common headers/footers
    text = re.sub(r'(?i)^(received|accepted|published|doi|copyright|license|conflict|funding).*$', '', text, flags=re.MULTILINE)
    # Remove URLs
    text = re.sub(r'https?://\S+', '', text)
    # Remove email addresses
    text = re.sub(r'\S+@\S+\.\S+', '', text)
    # Remove excessive whitespace
    text = re.sub(r'\s+', ' ', text)
    # Remove very short lines (likely artifacts)
    lines = text.split('\n')
    lines = [l for l in lines if len(l.strip()) > 10 or not l.strip()]
    text = '\n'.join(lines)
    return text.strip()


def chunk_paper_text(text: str, paper_id: str, source: str,
                     chunk_size: int = 600, overlap: int = 150) -> List[Dict]:
    """Split paper text into overlapping chunks with metadata"""
    sentences = re.split(r'(?<=[.!?])\s+', text)
    chunks = []
    current = ""
    chunk_idx = 0

    for sent in sentences:
        if len(current) + len(sent) > chunk_size and current:
            chunks.append({
                "chunk_id": f"{paper_id}_chunk_{chunk_idx}",
                "source": source,
                "conditions": extract_conditions(current),
                "content": current.strip(),
                "chunk_type": "academic_paper",
            })
            chunk_idx += 1
            words = current.split()
            current = " ".join(words[-overlap // 5:]) + " " + sent
        else:
            current += " " + sent

    if current.strip():
        chunks.append({
            "chunk_id": f"{paper_id}_chunk_{chunk_idx}",
            "source": source,
            "conditions": extract_conditions(current),
            "content": current.strip(),
            "chunk_type": "academic_paper",
        })

    return chunks


def extract_conditions(text: str) -> List[str]:
    """Extract veterinary dermatological condition names from text"""
    conditions = []
    condition_patterns = [
        r'atopic dermatitis', r'pyoderma', r'demodicosis', r'malassezia',
        r'dermatophytosis', r'pemphigus', r'sebaceous adenitis',
        r'hypothyroidism', r'hyperadrenocorticism', r'otitis externa',
        r'food allergy', r'flea allergy', r'contact dermatitis',
        r'acral lick', r'interdigital furunculosis', r'folliculitis',
        r'seborrhea', r'alopecia', r'cutaneous lymphoma', r'mast cell tumor',
        r'eosinophilic granuloma', r'feline acne', r'ringworm',
        r'scabies', r'sarcoptic mange', r'zinc-responsive',
        r'lupus erythematosus', r'vasculitis', r'erythema multiforme',
    ]
    text_lower = text.lower()
    for pattern in condition_patterns:
        if re.search(pattern, text_lower):
            conditions.append(pattern)
    return list(set(conditions))[:5]  # Max 5 conditions per chunk


# ============================================================
# Anna's Archive Scraper
# ============================================================

class AnnasArchiveScraper:
    """Search and download papers from Anna's Archive"""

    BASE_URL = "https://annas-archive.org"

    SEARCH_URL = f"{BASE_URL}/search"

    def __init__(self, download_dir: str = None):
        self.download_dir = download_dir or str(PAPERS_DIR / "annas")
        os.makedirs(self.download_dir, exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                          "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        })

    def search(self, query: str, max_results: int = 20) -> List[Dict]:
        """Search Anna's Archive for papers matching query"""
        log.info(f"[Anna's] Searching: '{query}'")
        results = []

        try:
            # Anna's Archive search endpoint
            params = {"q": query, "ext": "pdf", "sort": "newest"}
            resp = self.session.get(self.SEARCH_URL, params=params, timeout=30)
            resp.raise_for_status()

            # Parse search results from HTML
            # Look for MD5 links and titles
            html = resp.text

            # Pattern: /md5/{hash} links with titles
            md5_pattern = re.compile(
                r'href="/md5/([a-f0-9]{32})"[^>]*>.*?<[^>]*>([^<]+)',
                re.DOTALL
            )
            matches = md5_pattern.findall(html)

            for i, (md5_hash, title) in enumerate(matches[:max_results]):
                title = title.strip()[:200]
                results.append({
                    "id": f"annas_{md5_hash[:12]}",
                    "md5": md5_hash,
                    "title": title,
                    "url": f"{self.BASE_URL}/md5/{md5_hash}",
                    "source": "annas_archive",
                })

            # Alternative: try JSON API if available
            if not results:
                results = self._search_json_api(query, max_results)

        except Exception as e:
            log.error(f"[Anna's] Search failed: {e}")

        log.info(f"[Anna's] Found {len(results)} results for '{query}'")
        return results

    def _search_json_api(self, query: str, max_results: int) -> List[Dict]:
        """Try Anna's Archive JSON API (if available)"""
        results = []
        try:
            # Anna's Archive might have a search API at /search.json
            api_url = f"{self.BASE_URL}/search.json"
            params = {"q": query, "ext": "pdf"}
            resp = self.session.get(api_url, params=params, timeout=30)
            if resp.status_code == 200:
                data = resp.json()
                for item in data.get("hits", data if isinstance(data, list) else [])[:max_results]:
                    md5 = item.get("md5", item.get("id", ""))
                    title = item.get("title", "Unknown")
                    results.append({
                        "id": f"annas_{md5[:12]}",
                        "md5": md5,
                        "title": title,
                        "url": f"{self.BASE_URL}/md5/{md5}",
                        "source": "annas_archive",
                    })
        except Exception:
            pass
        return results

    def download(self, result: Dict) -> Optional[str]:
        """Download a paper PDF from Anna's Archive"""
        md5 = result.get("md5", "")
        if not md5:
            return None

        # Check if already downloaded
        dest = os.path.join(self.download_dir, f"{result['id']}.pdf")
        if os.path.exists(dest) and os.path.getsize(dest) > 1000:
            log.info(f"[Anna's] Already downloaded: {result['id']}")
            return dest

        try:
            # Try various mirror endpoints
            mirrors = [
                f"{self.BASE_URL}/slow_download/{md5}/0",
                f"{self.BASE_URL}/fast_download/{md5}/0",
            ]

            for mirror_url in mirrors:
                try:
                    resp = self.session.get(mirror_url, timeout=60, allow_redirects=True)
                    if resp.status_code == 200 and len(resp.content) > 1000:
                        content_type = resp.headers.get("Content-Type", "")
                        if "pdf" in content_type or resp.content[:4] == b'%PDF':
                            with open(dest, 'wb') as f:
                                f.write(resp.content)
                            log.info(f"[Anna's] Downloaded: {result['id']} ({len(resp.content)} bytes)")
                            return dest
                except Exception:
                    continue

            log.warning(f"[Anna's] Could not download: {result['id']}")
            return None

        except Exception as e:
            log.error(f"[Anna's] Download error: {e}")
            return None

    def harvest(self, queries: List[str], max_per_query: int = 10) -> List[Dict]:
        """Harvest papers from Anna's Archive for multiple queries"""
        all_papers = []
        seen_md5 = set()

        for query in queries:
            results = self.search(query, max_results=max_per_query)
            for result in results:
                if result["md5"] in seen_md5:
                    continue
                seen_md5.add(result["md5"])
                pdf_path = self.download(result)
                if pdf_path:
                    result["pdf_path"] = pdf_path
                    all_papers.append(result)
            time.sleep(2)  # Be nice to the server

        return all_papers


# ============================================================
# PubMed / PMC Scraper
# ============================================================

class PubMedScraper:
    """Search and download papers from PubMed / PubMed Central"""

    ESEARCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
    EFETCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
    ELINK_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi"
    PMC_OA_URL = "https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi"

    def __init__(self, download_dir: str = None, api_key: str = ""):
        self.download_dir = download_dir or str(PAPERS_DIR / "pubmed")
        os.makedirs(self.download_dir, exist_ok=True)
        self.api_key = api_key or os.environ.get("NCBI_API_KEY", "")
        self.session = requests.Session()

    def search(self, query: str, max_results: int = 50) -> List[Dict]:
        """Search PubMed for papers matching query"""
        log.info(f"[PubMed] Searching: '{query}'")
        results = []

        params = {
            "db": "pubmed",
            "term": f"{query} AND (dogs OR canine OR feline OR cats OR veterinary)",
            "retmax": max_results,
            "retmode": "json",
            "sort": "relevance",
        }
        if self.api_key:
            params["api_key"] = self.api_key

        try:
            resp = self.session.get(self.ESEARCH_URL, params=params, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            pmids = data.get("esearchresult", {}).get("idlist", [])

            if pmids:
                # Fetch details
                details = self._fetch_details(pmids)
                for pmid, detail in zip(pmids, details):
                    results.append({
                        "id": f"pubmed_{pmid}",
                        "pmid": pmid,
                        "title": detail.get("title", "Unknown"),
                        "authors": detail.get("authors", ""),
                        "journal": detail.get("journal", ""),
                        "year": detail.get("year", ""),
                        "abstract": detail.get("abstract", ""),
                        "doi": detail.get("doi", ""),
                        "source": "pubmed",
                    })

        except Exception as e:
            log.error(f"[PubMed] Search failed: {e}")

        log.info(f"[PubMed] Found {len(results)} results for '{query}'")
        return results

    def _fetch_details(self, pmids: List[str]) -> List[Dict]:
        """Fetch paper details from PubMed (XML format)"""
        params = {
            "db": "pubmed",
            "id": ",".join(pmids),
            "retmode": "xml",
            "rettype": "abstract",
        }
        if self.api_key:
            params["api_key"] = self.api_key

        try:
            resp = self.session.get(self.EFETCH_URL, params=params, timeout=30)
            resp.raise_for_status()
            xml_text = resp.text

            details = []
            # Parse each PubmedArticle
            articles = re.split(r'<PubmedArticle>', xml_text)
            for article_xml in articles[1:]:  # skip content before first article
                # Title
                title_match = re.search(r'<ArticleTitle>(.*?)</ArticleTitle>', article_xml, re.DOTALL)
                title = title_match.group(1).strip() if title_match else "Unknown"
                # Clean HTML tags from title
                title = re.sub(r'<[^>]+>', '', title)

                # Authors
                author_matches = re.findall(
                    r'<Author.*?>.*?<LastName>(.*?)</LastName>.*?<ForeName>(.*?)</ForeName>.*?</Author>',
                    article_xml, re.DOTALL
                )
                authors = ", ".join(f"{ln} {fn[:1]}" for ln, fn in author_matches[:3])
                if len(author_matches) > 3:
                    authors += " et al."

                # Journal
                journal_match = re.search(r'<ISOAbbreviation>(.*?)</ISOAbbreviation>', article_xml)
                journal = journal_match.group(1) if journal_match else ""

                # Year
                year_match = re.search(r'<PubDate>.*?<Year>(.*?)</Year>.*?</PubDate>', article_xml, re.DOTALL)
                if not year_match:
                    year_match = re.search(r'<PubDate>.*?<MedlineDate>(.*?)</MedlineDate>.*?</PubDate>', article_xml, re.DOTALL)
                year = year_match.group(1).strip()[:4] if year_match else ""

                # Abstract
                abstract_parts = re.findall(r'<AbstractText[^>]*>(.*?)</AbstractText>', article_xml, re.DOTALL)
                abstract = " ".join(re.sub(r'<[^>]+>', '', part) for part in abstract_parts)

                # DOI
                doi_match = re.search(r'<ArticleId IdType="doi">(.*?)</ArticleId>', article_xml)
                doi = doi_match.group(1) if doi_match else ""

                details.append({
                    "title": title,
                    "authors": authors,
                    "journal": journal,
                    "year": year,
                    "abstract": abstract,
                    "doi": doi,
                })

            # Pad if we got fewer details than pmids
            while len(details) < len(pmids):
                details.append({})

            return details[:len(pmids)]

        except Exception as e:
            log.error(f"[PubMed] Fetch details failed: {e}")
            return [{}] * len(pmids)

    def fetch_pmc_fulltext(self, pmid: str) -> Optional[str]:
        """Try to fetch full text from PubMed Central (open access)"""
        try:
            # Find PMC ID from PMID
            params = {
                "dbfrom": "pubmed",
                "db": "pmc",
                "id": pmid,
                "retmode": "json",
            }
            if self.api_key:
                params["api_key"] = self.api_key

            resp = self.session.get(self.ELINK_URL, params=params, timeout=15)
            resp.raise_for_status()
            data = resp.json()

            linksets = data.get("linksets", [])
            pmcid = None
            for ls in linksets:
                for linksetdb in ls.get("linksetdbs", []):
                    for link in linksetdb.get("links", []):
                        pmcid = f"PMC{link}"
                        break

            if not pmcid:
                return None

            # Fetch full text XML from PMC
            params2 = {
                "db": "pmc",
                "id": pmcid.replace("PMC", ""),
                "rettype": "xml",
            }
            resp2 = self.session.get(self.EFETCH_URL, params=params2, timeout=30)
            if resp2.status_code == 200:
                # Extract text from XML
                text = self._xml_to_text(resp2.text)
                return text if len(text) > 500 else None

        except Exception as e:
            log.debug(f"[PMC] Full text not available for PMID {pmid}: {e}")

        return None

    def _xml_to_text(self, xml_text: str) -> str:
        """Extract readable text from PMC XML"""
        # Simple XML text extraction
        text = re.sub(r'<xref[^>]*>.*?</xref>', '', xml_text)
        text = re.sub(r'<ext-link[^>]*>.*?</ext-link>', '', text)
        text = re.sub(r'<fig[^>]*>.*?</fig>', '', text, flags=re.DOTALL)
        text = re.sub(r'<table-wrap[^>]*>.*?</table-wrap>', '', text, flags=re.DOTALL)
        text = re.sub(r'<supplementary-material[^>]*>.*?</supplementary-material>', '', text, flags=re.DOTALL)
        text = re.sub(r'<ref-list[^>]*>.*?</ref-list>', '', text, flags=re.DOTALL)
        text = re.sub(r'<[^>]+>', ' ', text)
        text = re.sub(r'\s+', ' ', text)
        return text.strip()

    def harvest(self, queries: List[str], max_per_query: int = 20) -> List[Dict]:
        """Harvest papers from PubMed for multiple queries"""
        all_papers = []
        seen_pmids = set()

        for query in queries:
            results = self.search(query, max_results=max_per_query)
            for result in results:
                pmid = result.get("pmid", "")
                if pmid in seen_pmids:
                    continue
                seen_pmids.add(pmid)

                # Try to get full text from PMC
                fulltext = self.fetch_pmc_fulltext(pmid)
                if fulltext:
                    # Save full text
                    dest = os.path.join(self.download_dir, f"{result['id']}.txt")
                    with open(dest, 'w', encoding='utf-8') as f:
                        f.write(fulltext)
                    result["fulltext_path"] = dest
                    result["has_fulltext"] = True
                else:
                    # Use abstract only
                    result["has_fulltext"] = False
                    if result.get("abstract"):
                        dest = os.path.join(self.download_dir, f"{result['id']}_abstract.txt")
                        with open(dest, 'w', encoding='utf-8') as f:
                            f.write(result["abstract"])
                        result["fulltext_path"] = dest

                all_papers.append(result)

            time.sleep(0.5)  # NCBI rate limit

        return all_papers


# ============================================================
# Semantic Scholar Scraper
# ============================================================

class SemanticScholarScraper:
    """Search papers via Semantic Scholar API (free, no key required)"""

    SEARCH_URL = "https://api.semanticscholar.org/graph/v1/paper/search"
    PAPER_URL = "https://api.semanticscholar.org/graph/v1/paper"

    def __init__(self, download_dir: str = None):
        self.download_dir = download_dir or str(PAPERS_DIR / "semantic")
        os.makedirs(self.download_dir, exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "VetVoice/1.0"})

    def _request_with_retry(self, url: str, params: dict, max_retries: int = 3) -> Optional[requests.Response]:
        """Make HTTP request with retry on rate limit"""
        for attempt in range(max_retries):
            try:
                resp = self.session.get(url, params=params, timeout=30)
                if resp.status_code == 429:
                    wait = 2 ** (attempt + 2)  # 4, 8, 16 seconds
                    log.warning(f"[Semantic] Rate limited, waiting {wait}s (attempt {attempt+1}/{max_retries})")
                    time.sleep(wait)
                    continue
                resp.raise_for_status()
                return resp
            except requests.exceptions.HTTPError as e:
                if resp.status_code == 429 and attempt < max_retries - 1:
                    continue
                raise
            except Exception as e:
                if attempt < max_retries - 1:
                    time.sleep(3)
                    continue
                raise
        return None

    def search(self, query: str, max_results: int = 30) -> List[Dict]:
        """Search Semantic Scholar for papers"""
        log.info(f"[Semantic] Searching: '{query}'")
        results = []

        params = {
            "query": query,
            "limit": min(max_results, 100),
            "fields": "title,abstract,year,authors,journal,externalIds,url,openAccessPdf",
        }

        try:
            resp = self._request_with_retry(self.SEARCH_URL, params)
            if resp is None:
                log.error(f"[Semantic] All retries exhausted for query: '{query}'")
                return results
            data = resp.json()

            for paper in data.get("data", []):
                paper_id = paper.get("paperId", "")[:12]
                ext_ids = paper.get("externalIds", {})
                doi = ext_ids.get("DOI", "")

                authors_list = paper.get("authors", [])
                authors = ", ".join(a.get("name", "") for a in authors_list[:3])
                if len(authors_list) > 3:
                    authors += " et al."

                oa_pdf = paper.get("openAccessPdf", {})
                pdf_url = oa_pdf.get("url", "") if oa_pdf else ""

                results.append({
                    "id": f"semantic_{paper_id}",
                    "title": paper.get("title", "Unknown"),
                    "authors": authors,
                    "year": str(paper.get("year", "")),
                    "journal": paper.get("journal", {}).get("name", "") if paper.get("journal") else "",
                    "abstract": paper.get("abstract", "") or "",
                    "doi": doi,
                    "pdf_url": pdf_url,
                    "url": paper.get("url", ""),
                    "source": "semantic_scholar",
                })

        except Exception as e:
            log.error(f"[Semantic] Search failed: {e}")

        log.info(f"[Semantic] Found {len(results)} results for '{query}'")
        return results

    def download_pdf(self, result: Dict) -> Optional[str]:
        """Download open-access PDF from Semantic Scholar"""
        pdf_url = result.get("pdf_url", "")
        if not pdf_url:
            return None

        dest = os.path.join(self.download_dir, f"{result['id']}.pdf")
        if os.path.exists(dest) and os.path.getsize(dest) > 1000:
            return dest

        try:
            resp = self.session.get(pdf_url, timeout=60, allow_redirects=True,
                                     headers={"User-Agent": "VetVoice/1.0"})
            if resp.status_code == 200 and resp.content[:4] == b'%PDF':
                with open(dest, 'wb') as f:
                    f.write(resp.content)
                log.info(f"[Semantic] Downloaded PDF: {result['id']}")
                return dest
        except Exception as e:
            log.warning(f"[Semantic] PDF download failed: {e}")

        return None

    def harvest(self, queries: List[str], max_per_query: int = 15) -> List[Dict]:
        """Harvest papers from Semantic Scholar"""
        all_papers = []
        seen_ids = set()

        for query in queries:
            results = self.search(query, max_results=max_per_query)
            for result in results:
                if result["id"] in seen_ids:
                    continue
                seen_ids.add(result["id"])

                # Try downloading PDF
                pdf_path = self.download_pdf(result)
                if pdf_path:
                    result["pdf_path"] = pdf_path
                else:
                    # Save abstract as text file
                    if result.get("abstract"):
                        dest = os.path.join(self.download_dir, f"{result['id']}_abstract.txt")
                        with open(dest, 'w', encoding='utf-8') as f:
                            f.write(result["abstract"])
                        result["fulltext_path"] = dest

                all_papers.append(result)

            time.sleep(1)  # Rate limit

        return all_papers


# ============================================================
# RAG Index Builder
# ============================================================

class RAGIndexBuilder:
    """Build and update FAISS + TF-IDF RAG index"""

    def __init__(self, knowledge_dir: str = None):
        self.knowledge_dir = knowledge_dir or str(KNOWLEDGE_DIR)
        os.makedirs(self.knowledge_dir, exist_ok=True)

    def load_existing_chunks(self) -> List[Dict]:
        """Load existing chunks from retrieval store"""
        store_path = os.path.join(self.knowledge_dir, "vet_derm_retrieval_store.json")
        if os.path.exists(store_path):
            with open(store_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        return []

    def paper_to_chunks(self, paper: Dict) -> List[Dict]:
        """Convert a paper into RAG chunks"""
        paper_id = paper.get("id", hashlib.md5(paper.get("title", "").encode()).hexdigest()[:12])
        source_name = paper.get("source", "unknown")

        # Try PDF extraction first
        text = None
        pdf_path = paper.get("pdf_path")
        if pdf_path and os.path.exists(pdf_path):
            text = extract_text_from_pdf(pdf_path)

        # Try fulltext file
        if not text:
            fulltext_path = paper.get("fulltext_path")
            if fulltext_path and os.path.exists(fulltext_path):
                with open(fulltext_path, 'r', encoding='utf-8') as f:
                    text = f.read()

        # Fallback to abstract
        if not text and paper.get("abstract"):
            title = paper.get("title", "")
            authors = paper.get("authors", "")
            journal = paper.get("journal", "")
            year = paper.get("year", "")
            abstract = paper.get("abstract", "")
            text = f"{title}. {authors}. {journal} {year}. {abstract}"

        if not text or len(text.strip()) < 100:
            return []

        # Clean and chunk
        clean_text = clean_paper_text(text)
        chunks = chunk_paper_text(
            clean_text,
            paper_id=paper_id,
            source=f"paper:{source_name}:{paper.get('title', 'Unknown')[:80]}",
        )

        # Add paper metadata to each chunk
        for chunk in chunks:
            chunk["paper_title"] = paper.get("title", "")
            chunk["paper_year"] = paper.get("year", "")
            chunk["paper_doi"] = paper.get("doi", "")
            chunk["paper_journal"] = paper.get("journal", "")

        return chunks

    def merge_chunks(self, existing: List[Dict], new_chunks: List[Dict]) -> List[Dict]:
        """Merge new chunks into existing, avoiding duplicates"""
        existing_ids = {c.get("chunk_id", "") for c in existing}
        merged = list(existing)

        for chunk in new_chunks:
            if chunk["chunk_id"] not in existing_ids:
                merged.append(chunk)
                existing_ids.add(chunk["chunk_id"])

        return merged

    def build_index(self, chunks: List[Dict]) -> None:
        """Build TF-IDF + FAISS index from chunks"""
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.preprocessing import normalize
        import faiss

        log.info(f"Building index from {len(chunks)} chunks...")
        texts = [c["content"] for c in chunks]

        vectorizer = TfidfVectorizer(
            max_features=10000,
            ngram_range=(1, 2),
            stop_words='english',
            min_df=1,
            max_df=0.95,
        )
        tfidf = vectorizer.fit_transform(texts).toarray().astype('float32')
        tfidf = normalize(tfidf, norm='l2')

        index = faiss.IndexFlatIP(tfidf.shape[1])
        index.add(tfidf)

        # Save
        faiss.write_index(index, os.path.join(self.knowledge_dir, "vet_derm_faiss.index"))
        with open(os.path.join(self.knowledge_dir, "vet_derm_vectorizer.pkl"), 'wb') as f:
            import pickle
            pickle.dump(vectorizer, f)

        store = [{
            "chunk_id": c["chunk_id"],
            "source": c["source"],
            "conditions": c.get("conditions", []),
            "content": c["content"],
            "chunk_type": c.get("chunk_type", "general"),
        } for c in chunks]

        with open(os.path.join(self.knowledge_dir, "vet_derm_retrieval_store.json"), 'w') as f:
            json.dump(store, f, ensure_ascii=False, indent=2)

        log.info(f"Built index: {index.ntotal} vectors, {tfidf.shape[1]} dims")

    def upload_to_hub(self) -> None:
        """Upload knowledge base to HuggingFace Hub"""
        from huggingface_hub import HfApi

        api = HfApi()
        for fname in os.listdir(self.knowledge_dir):
            if fname.endswith(('.index', '.pkl', '.json')):
                api.upload_file(
                    path_or_fileobj=os.path.join(self.knowledge_dir, fname),
                    path_in_repo=fname,
                    repo_id=HF_REPO,
                    repo_type="model",
                    token=HF_TOKEN,
                )
                log.info(f"Uploaded: {fname}")


# ============================================================
# Metadata Tracker
# ============================================================

def load_metadata() -> Dict:
    """Load papers metadata tracker"""
    if os.path.exists(METADATA_FILE):
        with open(METADATA_FILE, 'r') as f:
            return json.load(f)
    return {"papers": [], "last_harvest": "", "total_chunks": 0}


def save_metadata(metadata: Dict) -> None:
    """Save papers metadata tracker"""
    os.makedirs(os.path.dirname(METADATA_FILE), exist_ok=True)
    with open(METADATA_FILE, 'w') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)


# ============================================================
# Main Pipeline
# ============================================================

def harvest_papers(source: str, queries: List[str], max_per_query: int = 10) -> List[Dict]:
    """Harvest papers from specified source(s)"""
    all_papers = []

    if source in ("annas", "all"):
        scraper = AnnasArchiveScraper()
        papers = scraper.harvest(queries, max_per_query=max_per_query)
        all_papers.extend(papers)
        log.info(f"Anna's Archive: {len(papers)} papers harvested")

    if source in ("pubmed", "all"):
        scraper = PubMedScraper()
        papers = scraper.harvest(queries, max_per_query=max_per_query)
        all_papers.extend(papers)
        log.info(f"PubMed: {len(papers)} papers harvested")

    if source in ("semantic", "all"):
        scraper = SemanticScholarScraper()
        papers = scraper.harvest(queries, max_per_query=max_per_query)
        all_papers.extend(papers)
        log.info(f"Semantic Scholar: {len(papers)} papers harvested")

    return all_papers


def process_papers_to_rag(papers: List[Dict], rebuild: bool = False) -> int:
    """Convert harvested papers to RAG chunks and rebuild index"""
    builder = RAGIndexBuilder()

    # Load existing chunks
    existing = builder.load_existing_chunks() if not rebuild else []
    log.info(f"Existing chunks: {len(existing)}")

    # Convert papers to chunks
    new_chunks = []
    for paper in papers:
        chunks = builder.paper_to_chunks(paper)
        new_chunks.extend(chunks)

    log.info(f"New chunks from papers: {len(new_chunks)}")

    if not new_chunks and not rebuild:
        log.warning("No new chunks generated")
        return 0

    # Merge and build
    merged = builder.merge_chunks(existing, new_chunks)
    log.info(f"Total chunks after merge: {len(merged)}")

    builder.build_index(merged)

    # Update metadata
    metadata = load_metadata()
    metadata["last_harvest"] = datetime.now().isoformat()
    metadata["total_chunks"] = len(merged)
    for paper in papers:
        metadata["papers"].append({
            "id": paper.get("id", ""),
            "title": paper.get("title", ""),
            "source": paper.get("source", ""),
            "year": paper.get("year", ""),
            "doi": paper.get("doi", ""),
            "harvested_at": datetime.now().isoformat(),
        })
    save_metadata(metadata)

    return len(new_chunks)


def ingest_local_pdfs(directory: str) -> int:
    """Ingest PDFs from a local directory into RAG"""
    pdf_files = list(Path(directory).glob("**/*.pdf"))
    log.info(f"Found {len(pdf_files)} PDFs in {directory}")

    papers = []
    for pdf_path in pdf_files:
        papers.append({
            "id": f"local_{pdf_path.stem[:30]}",
            "title": pdf_path.stem,
            "source": "local_pdf",
            "pdf_path": str(pdf_path),
        })

    return process_papers_to_rag(papers)


def main():
    parser = argparse.ArgumentParser(
        description="VetPaper Harvester — Academic Paper Parser for VetVoice RAG",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Harvest from Anna's Archive
  python paper_harvester.py --source annas --query "canine atopic dermatitis" --max 20

  # Harvest from PubMed
  python paper_harvester.py --source pubmed --query "feline dermatophytosis" --max 50

  # Harvest from Semantic Scholar
  python paper_harvester.py --source semantic --query "dog pyoderma" --max 30

  # Harvest from all sources
  python paper_harvester.py --source all --query "veterinary dermatology" --max 20

  # Batch harvest all veterinary dermatology queries
  python paper_harvester.py --source all --batch --max 10

  # Ingest local PDFs
  python paper_harvester.py --local-dir /path/to/pdfs

  # Rebuild FAISS index from all collected data
  python paper_harvester.py --rebuild

  # Rebuild and upload to HF Hub
  python paper_harvester.py --rebuild --upload
        """,
    )

    parser.add_argument("--source", choices=["annas", "pubmed", "semantic", "all"],
                        default="all", help="Source to harvest from")
    parser.add_argument("--query", type=str, help="Search query")
    parser.add_argument("--max", type=int, default=10, help="Max results per query")
    parser.add_argument("--batch", action="store_true",
                        help="Use built-in veterinary dermatology queries")
    parser.add_argument("--local-dir", type=str, help="Ingest PDFs from local directory")
    parser.add_argument("--rebuild", action="store_true",
                        help="Rebuild FAISS index from all collected data")
    parser.add_argument("--upload", action="store_true",
                        help="Upload to HuggingFace Hub after processing")
    parser.add_argument("--no-harvest", action="store_true",
                        help="Skip harvesting, only process/rebuild")

    args = parser.parse_args()

    # Rebuild-only mode
    if args.rebuild and args.no_harvest:
        log.info("Rebuilding FAISS index from existing data...")
        builder = RAGIndexBuilder()
        existing = builder.load_existing_chunks()
        if existing:
            builder.build_index(existing)
            if args.upload:
                builder.upload_to_hub()
        return

    # Local PDF ingestion
    if args.local_dir:
        if not os.path.isdir(args.local_dir):
            log.error(f"Directory not found: {args.local_dir}")
            sys.exit(1)
        count = ingest_local_pdfs(args.local_dir)
        log.info(f"Ingested {count} new chunks from local PDFs")
        if args.upload:
            RAGIndexBuilder().upload_to_hub()
        return

    # Need a query or batch mode
    if not args.query and not args.batch:
        log.error("Provide --query or use --batch with built-in queries")
        parser.print_help()
        sys.exit(1)

    # Determine queries
    queries = [args.query] if args.query else VET_DERM_QUERIES
    log.info(f"Using {len(queries)} queries")

    # Harvest papers
    papers = harvest_papers(args.source, queries, max_per_query=args.max)
    log.info(f"Total papers harvested: {len(papers)}")

    if papers:
        # Process into RAG
        new_chunks = process_papers_to_rag(papers, rebuild=args.rebuild)
        log.info(f"Added {new_chunks} new chunks to RAG")

        # Upload if requested
        if args.upload:
            builder = RAGIndexBuilder()
            builder.upload_to_hub()
            log.info("Uploaded to HuggingFace Hub!")


if __name__ == "__main__":
    main()
