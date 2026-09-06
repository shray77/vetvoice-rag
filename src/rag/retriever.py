"""VetVoice RAG Retriever — FAISS + TF-IDF retrieval for veterinary dermatology.

Loads knowledge base from local `knowledge_base/` directory first.
Falls back to Hugging Face Hub download if local files are missing.
"""

import json
import os
import pickle
import re
from pathlib import Path

import faiss
from sklearn.preprocessing import normalize

from src.settings import get_settings

# ============================================================
# Russian → English medical term translation for RAG retrieval
# ============================================================
RU_EN_TERMS = {
    # Symptoms
    "чешет": "pruritus itchy scratching", "зуд": "pruritus itchy",
    "чесаться": "pruritus itchy scratching", "красная": "erythema red inflamed",
    "красное": "erythema red", "воспалённая": "inflamed inflammation",
    "воспаление": "inflammation", "выпадает шерсть": "alopecia hair loss",
    "выпадение шерсти": "alopecia hair loss", "лысеет": "alopecia hair loss bald",
    "лысины": "alopecia bald patches", "перхоть": "scale scaling seborrhea dandruff",
    "корки": "crust crusted", "прыщики": "papule pustule pustules pimples",
    "гнойнички": "pustule pyoderma bacterial", "пятна": "patch macule",
    "ранки": "erosion ulcer wound", "язвочки": "ulcer erosion",
    "шишка": "nodule tumor mass", "опухоль": "tumor neoplasm mass",
    "запах": "odor smell malodor", "плохой запах": "malodor smell odor",
    "жирная кожа": "seborrhea oleosa greasy skin", "сухая кожа": "seborrhea sicca dry skin",
    "тёмная кожа": "hyperpigmentation dark skin", "пигментация": "hyperpigmentation pigmentation",
    # Body parts
    "лапы": "paws feet interdigital", "морда": "face facial",
    "уши": "ears otitis ear", "живот": "ventrum abdomen belly inguinal",
    "спина": "dorsum back", "грудь": "chest axillae",
    "подмышки": "axillae armpit", "паха": "inguinal groin",
    "нос": "nose nasal planum", "глаза": "eyes periocular",
    "хвост": "tail", "анус": "perianal anal",
    # Breeds
    "французский бульдог": "French Bulldog brachycephalic",
    "бульдог": "Bulldog brachycephalic", "мопс": "Pug brachycephalic",
    "лабрадор": "Labrador Retriever", "овчарка": "German Shepherd",
    "немецкая овчарка": "German Shepherd", "терьер": "Terrier West Highland",
    "вест хайленд": "West Highland White Terrier", "шарпей": "Shar-Pei",
    "пудель": "Poodle", "спаниель": "Cocker Spaniel",
    "чихуахуа": "Chihuahua", "корги": "Corgi", "хаски": "Husky",
    "шпиц": "Spitz", "йорк": "Yorkshire Terrier",
    "йоркширский терьер": "Yorkshire Terrier", "такса": "Dachshund",
    "доберман": "Doberman Pinscher", "ретривер": "Golden Retriever",
    "голден ретривер": "Golden Retriever", "чау-чау": "Chow Chow",
    "акита": "Akita", "ротвейлер": "Rottweiler", "бассет": "Basset Hound",
    "бигль": "Beagle", "далматин": "Dalmatian", "боксёр": "Boxer",
    "самоед": "Samoyed", "мальтезе": "Maltese", "ши-тцу": "Shih Tzu",
    "кокер-спаниель": "Cocker Spaniel", "ризеншнауцер": "Giant Schnauzer",
    # Diseases
    "аллергия": "allergy atopic dermatitis allergic",
    "атопический дерматит": "atopic dermatitis atopy",
    "демодекоз": "demodicosis Demodex mange",
    "чесотка": "sarcoptic mange scabies",
    "лишай": "dermatophytosis ringworm fungal",
    "стригущий лишай": "dermatophytosis ringworm",
    "малассезия": "Malassezia yeast",
    "дрожжевая инфекция": "Malassezia yeast infection",
    "пиодермия": "pyoderma bacterial skin infection",
    "фолликулит": "folliculitis", "себорея": "seborrhea",
    "гипотиреоз": "hypothyroidism thyroid",
    "гиперадренокортицизм": "hyperadrenocorticism Cushing",
    "кушинг": "Cushing hyperadrenocorticism",
    "пемфигус": "pemphigus autoimmune",
    "аутоиммунное": "autoimmune pemphigus SLE",
    "отит": "otitis externa ear infection",
    "горячая точка": "hot spot acute moist dermatitis",
    "экзема": "eczema dermatitis",
    "интертриго": "intertrigo skin fold dermatitis",
    "облысение": "alopecia hair loss",
    "облизывает лапы": "lick paw atopic dermatitis",
    "вылизывает": "lick acral lick granuloma",
    "мокнет": "moist weeping exudative",
    "кровоточит": "bleeding hemorrhagic ulcer",
    # Animals
    "собака": "dog canine", "щенок": "puppy young dog",
    "кот": "cat feline", "кошка": "cat feline",
    "маленький": "young small", "старый": "old geriatric senior",
}

# ============================================================
# English → Russian drug/disease name mapping (for EN queries)
# ============================================================
EN_RU_DRUG_TERMS = {
    "enrofloxacin": "энрофлоксацин",
    "amoxicillin": "амоксициллин",
    "doxycycline": "доксициклин",
    "tylosin": "тилозин",
    "ceftiofur": "цефтиофур",
    "maropitant": "маропитант",
    "ivermectin": "ивермектин",
    "doramectin": "дорамектин",
    "selamectin": "селамектин",
    "moxidectin": "моксидектин",
    "praziquantel": "празиквантел",
    "pyrantel": "пирантел",
    "febantel": "фебантел",
    "fenbendazole": "фенбендазол",
    "albendazole": "альбендазол",
    "ketoprofen": "кетопрофен",
    "carprofen": "карпрофен",
    "meloxicam": "мелоксикам",
    "dexamethasone": "дексаметазон",
    "prednisolone": "преднизолон",
    "gentamicin": "гентамицин",
    "kanamycin": "канамицин",
    "trimethoprim": "триметоприм",
    "sulfamethoxazole": "сульфаметоксазол",
    "metronidazole": "метронидазол",
    "florfenicol": "флорфеникол",
    "tulathromycin": "тулатромицин",
    "gamithromycin": "гамитромицин",
    "tilmicosin": "тилмикозин",
    "atropine": "атропин",
    "diazepam": "диазепам",
    "ketamine": "кетамин",
    "xylazine": "ксилазин",
    "propofol": "пропофол",
    "isoflurane": "изофлуран",
    "furosemide": "фуросемид",
    "digoxin": "дигоксин",
    "benzylpenicillin": "бензилпенициллин",
    "oxytetracycline": "окситетрациклин",
    "chloramphenicol": "хлорамфеникол",
    # Diseases
    "fmd": "ящур",
    "foot and mouth": "ящур",
    "rabies": "бешенство",
    "anthrax": "сибирская язва",
    "brucellosis": "бруцеллёз",
    "tuberculosis": "туберкулёз",
    "leptospirosis": "лептоспироз",
    "leishmaniasis": "лейшманиоз",
    "dermatophytosis": "дерматофития лишай",
    "ringworm": "лишай дерматофития",
    "mange": "чесотка",
    "demodicosis": "демодекоз",
    "otitis": "отит",
    "pyoderma": "пиодермия",
    "malassezia": "малассезия",
    "atopic dermatitis": "атопический дерматит",
    "cushing": "кушинг",
    "hypothyroidism": "гипотиреоз",
    # Animals
    "cattle": "крс",
    "cow": "крс",
    "bovine": "крс",
    "sheep": "мрс",
    "ovine": "мрс",
    "goat": "мрс",
    "pig": "свиньи",
    "swine": "свиньи",
    "porcine": "свиньи",
    "poultry": "птица",
    "chicken": "птица",
    "dog": "собака",
    "canine": "собака",
    "cat": "кошка",
    "feline": "кошка",
    "horse": "лошадь",
    "equine": "лошадь",
    "rabbit": "кролик",
    # Topics
    "side effects": "побочные эффекты",
    "side effect": "побочный эффект",
    "dosage": "доза дозировка",
    "dose": "доза",
    "treatment": "лечение",
    "contraindication": "противопоказание",
    "withdrawal": "период ожидания",
    "interaction": "взаимодействие",
    "antidote": "антидот",
    "poisoning": "отравление",
    # Extra high-frequency INNs likely to leak from JSON context
    "penicillin": "пенициллин",
    "amplicillin": "ампициллин",
    "ampicillin": "ампициллин",
    "cephalexin": "цефалексин",
    "cefazolin": "цефазолин",
    "clindamycin": "клиндамицин",
    "lincomycin": "линкомицин",
    "neomycin": "неомицин",
    "polymyxin": "полимиксин",
    "fipronil": "фипронил",
    "imidacloprid": "имидаклоприд",
    "permethrin": "перметрин",
    "pyrethrin": "пиретрин",
    "afoxolaner": "афоксоланер",
    "fluralaner": "флураланер",
    "lotilaner": "лотиланер",
    "praziquantel": "празиквантел",
    "levamisole": "левамизол",
    "clorsulon": "клорсулон",
    "toltrazuril": "толтразурил",
    "diclazuril": "диклазурил",
    "ponazuril": "поназурил",
    "marbofloxacin": "марбофлоксацин",
    "pradofloxacin": "прадофлоксацин",
    "gatifloxacin": "гатифлоксацин",
    "ciprofloxacin": "ципрофлоксацин",
    "enrofloxacin": "энрофлоксацин",
    "levofloxacin": "левофлоксацин",
    "azithromycin": "азитромицин",
    "clarithromycin": "кларитромицин",
    "erythromycin": "эритромицин",
    "metoclopramide": "метоклопрамид",
    "ondansetron": "ондансетрон",
    "maropitant": "маропитант",
    "butorphanol": "буторфанол",
    "buprenorphine": "бупренорфин",
    "tramadol": "трамадол",
    "gabapentin": "габапентин",
    "phenobarbital": "фенобарбитал",
    "levetiracetam": "леветирацетам",
    "insulin": "инсулин",
    "glargine": "гларгин",
    "detomidine": "детомидин",
    "romifidine": "ромифидин",
    "medetomidine": "медетомидин",
    "acepromazine": "ацепромазин",
    "midazolam": "мидазолам",
    "butorphanol": "буторфанол",
    "phenylephrine": "фенилэфрин",
    "epinephrine": "адреналин",
    "adrenaline": "адреналин",
    "norepinephrine": "норадреналин",
    "salbutamol": "сальбутамол",
    "aminophylline": "аминофиллин",
    "theophylline": "теофиллин",
    "heparin": "гепарин",
    "warfarin": "варфарин",
    "clopidogrel": "клопидогрел",
    "omeprazole": "омепразол",
    "ranitidine": "ранитидин",
    "famotidine": "фамотидин",
    "metronidazole": "метронидазол",
    "sulfasalazine": "сульфасалазин",
    "cholestyramine": "холестирамин",
    "ursodeoxycholic": "урсодезоксихолевая кислота",
    "ursodiol": "урсодезоксихолевая кислота",
    "methimazole": "метимазол",
    "levothyroxine": "левотироксин",
    "trilostane": "трилостан",
    "mitotane": "митотан",
    "desoxycorticosterone": "дезоксикортикостерон",
    "spironolactone": "спиронолактон",
    "furosemide": "фуросемид",
    "benazepril": "беназеприл",
    "enalapril": "энапалил",
    "pimobendan": "пимобендан",
    "atenolol": "атенолол",
    "diltiazem": "дилтиазем",
    "amlodipine": "амлодипин",
    "lidocaine": "лидокаин",
    "procainamide": "прокаинамид",
    "sotalol": "соталол",
    "doxycycline": "доксициклин",
    "tetracycline": "тетрациклин",
    "oxytetracycline": "окситетрациклин",
    "chloramphenicol": "хлорамфеникол",
    "gentamicin": "гентамицин",
    "amikacin": "амикацин",
    "tobramycin": "тобрамицин",
    "streptomycin": "стрептомицин",
    "enrofloxacin": "энрофлоксацин",
    "marbofloxacin": "марбофлоксацин",
}

# Reverse map for localizing LLM output: English/Latin term -> Russian.
# Used by ru_localize() to strip English drug/disease names that leak from RAG
# context (JSON `conditions`/`INN` fields) into the model's Russian answer.
_RU_LOCALIZE_MAP = {k.lower(): v for k, v in EN_RU_DRUG_TERMS.items()}


def ru_localize(text: str) -> str:
    """Replace Latin/English drug & disease names in LLM output with Russian.

    Targeted fix for the RAG leak where GLM copied raw EN INN names (e.g.
    ``prednisolone``, ``enrofloxacin``) from the retrieved context into its
    Russian-language answer. Only known terms from EN_RU_DRUG_TERMS are touched,
    so ordinary Russian text is left untouched.
    """
    if not text:
        return text
    for en, ru in sorted(_RU_LOCALIZE_MAP.items(), key=lambda x: -len(x[0])):
        # Whole-word, case-insensitive. Handles phrases like "atopic dermatitis".
        text = re.sub(rf"(?i)\b{re.escape(en)}\b", ru, text)
    return text


def translate_ru_to_en_query(text: str) -> str:
    """Translate Russian medical query to English for FAISS retrieval.

    Also handles reverse: English drug/disease names → Russian transliteration,
    so EN queries can match RU chunks in the index.
    """
    text_lower = text.lower()
    en_terms = []
    ru_terms = []

    # RU → EN
    sorted_ru = sorted(RU_EN_TERMS.items(), key=lambda x: len(x[0]), reverse=True)
    for ru_term, en_translation in sorted_ru:
        if ru_term in text_lower:
            en_terms.append(en_translation)

    # EN → RU
    sorted_en = sorted(EN_RU_DRUG_TERMS.items(), key=lambda x: len(x[0]), reverse=True)
    for en_term, ru_translation in sorted_en:
        if en_term in text_lower:
            ru_terms.append(ru_translation)

    en_words = re.findall(r'[a-zA-Z]+', text)
    parts = [text]
    if en_terms:
        parts.append(" ".join(en_terms))
    if en_words:
        parts.append(" ".join(en_words))
    if ru_terms:
        parts.append(" ".join(ru_terms))
    return " ".join(parts)


class VetDermRAG:
    """Retrieval-Augmented Generation for Veterinary Dermatology.

    Loading order:
      1. Local `knowledge_base/` directory next to the package (or REPO_ROOT env)
      2. Hugging Face Hub repo `shrayyyy/vet-derm-rag` (if HF_TOKEN is set)
    """

    # Default local dir = repo's `knowledge_base/` folder (one level up from `src/`)
    _DEFAULT_LOCAL_DIR = str(Path(__file__).resolve().parent.parent.parent / "knowledge_base")

    def __init__(
        self,
        repo_id: str | None = None,
        local_dir: str | None = None,
        hf_dir: str | None = None,
    ):
        cfg = get_settings()
        self.repo_id = repo_id or cfg.rag_repo_id
        # Приоритет: аргумент → VETVOICE_KB_DIR → config.yaml → <repo>/knowledge_base
        self.local_dir = (
            local_dir
            or os.environ.get("VETVOICE_KB_DIR")
            or (cfg.rag_local_dir if cfg.rag_local_dir else cfg.effective_local_dir)
        )
        self.hf_dir = hf_dir or cfg.rag_hf_dir
        self.index = None
        self.vectorizer = None
        self.documents: list[dict] = []
        self._load()

    def _load(self):
        """Load FAISS index, vectorizer, and documents — local first, then HF."""
        files = {
            "index": "vet_derm_faiss.index",
            "vectorizer": "vet_derm_vectorizer.pkl",
            "documents": "vet_derm_retrieval_store.json",
        }

        # Try local first
        local_paths = {
            k: Path(self.local_dir) / fname
            for k, fname in files.items()
        }
        if all(p.exists() for p in local_paths.values()):
            print(f"[RAG] Loading from local: {self.local_dir}")
            # faiss (swig) on Windows cannot open paths with non-ASCII chars
            # (e.g. Cyrillic "Администратор"). Copy to an ASCII temp path first.
            idx_read = local_paths["index"]
            tmp = None
            if os.name == "nt":
                try:
                    import shutil as _shutil
                    tmp = Path("D:/tmp_vet_rag_read.faiss")
                    _shutil.copy2(idx_read, tmp)
                    idx_read = tmp
                except Exception as e:  # noqa: BLE001
                    print(f"[RAG] warn: ASCII-tmp copy failed ({e}), trying direct")
            self.index = faiss.read_index(str(idx_read))
            if tmp is not None and tmp.exists():
                tmp.unlink(missing_ok=True)
            with open(local_paths["vectorizer"], "rb") as f:
                self.vectorizer = pickle.load(f)
            with open(local_paths["documents"], "r", encoding="utf-8") as f:
                self.documents = json.load(f)
            print(f"[RAG] Loaded: {self.index.ntotal} vectors, {len(self.documents)} docs (local)")
            return

        # Fallback: HF Hub
        print(f"[RAG] Local KB not found at {self.local_dir}, trying HF Hub...")
        try:
            from huggingface_hub import hf_hub_download
        except ImportError:
            raise RuntimeError(
                "Neither local KB nor huggingface_hub available. "
                "Run: python3 scripts/build_rag.py"
            )

        os.makedirs(self.hf_dir, exist_ok=True)
        # Репозиторий базы знаний публичный — токен не обязателен.
        # Он нужен только если репо сделают приватным.
        token = get_settings().hf_token or os.environ.get("HF_TOKEN") or None

        index_path = hf_hub_download(
            repo_id=self.repo_id, filename=files["index"],
            token=token, local_dir=self.hf_dir,
        )
        vec_path = hf_hub_download(
            repo_id=self.repo_id, filename=files["vectorizer"],
            token=token, local_dir=self.hf_dir,
        )
        doc_path = hf_hub_download(
            repo_id=self.repo_id, filename=files["documents"],
            token=token, local_dir=self.hf_dir,
        )

        self.index = faiss.read_index(index_path)
        with open(vec_path, "rb") as f:
            self.vectorizer = pickle.load(f)
        with open(doc_path, "r", encoding="utf-8") as f:
            self.documents = json.load(f)
        print(f"[RAG] Loaded: {self.index.ntotal} vectors, {len(self.documents)} docs (HF Hub)")

    def retrieve(
        self,
        query: str,
        top_k: int | None = None,
        min_score: float | None = None,
    ) -> list[dict]:
        """Retrieve relevant knowledge chunks for a query.

        Hybrid retrieval:
          1. TF-IDF + FAISS cosine similarity (semantic)
          2. Keyword boost: if query contains a token from a chunk's
             `conditions` field (case-insensitive), boost its score.

        Returns top_k chunks sorted by combined score.
        """
        if not self.index or not self.vectorizer:
            return []

        cfg = get_settings()
        top_k = top_k if top_k is not None else cfg.rag_top_k
        min_score = min_score if min_score is not None else cfg.rag_min_score

        search_query = translate_ru_to_en_query(query)
        query_vec = self.vectorizer.transform([search_query]).toarray().astype('float32')
        query_vec = normalize(query_vec, norm='l2')

        # Pull more candidates than top_k so we can re-rank with keyword boost
        fetch_k = min(top_k * 10, 50)
        distances, indices = self.index.search(query_vec, fetch_k)

        # Lowercase the query for keyword matching
        q_lower = query.lower()
        # Also include English-translated terms
        en_query = translate_ru_to_en_query(query).lower()

        results: list[dict] = []
        for dist, idx in zip(distances[0], indices[0]):
            if idx < 0 or idx >= len(self.documents):
                continue
            if dist < min_score:
                continue
            doc = self.documents[idx].copy()
            tfidf_score = float(dist)

            # Keyword boost: +0.30 per matched condition (max 0.90)
            conditions = doc.get("conditions") or []
            boost = 0.0
            matched = 0
            for cond in conditions:
                if not cond:
                    continue
                cond_l = cond.lower()
                if cond_l in q_lower or cond_l in en_query:
                    boost += 0.30
                    matched += 1
            boost = min(boost, 0.90)
            # Multiplier: if ≥1 condition matched, multiply tfidf by 1.5x
            multiplier = 1.5 if matched > 0 else 1.0

            doc["score"] = tfidf_score * multiplier + boost
            doc["tfidf_score"] = tfidf_score
            doc["keyword_boost"] = boost
            doc["keyword_matches"] = matched
            results.append(doc)

        # Re-sort by combined score, take top_k
        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:top_k]

    def format_context(
        self, results: list[dict], max_chars: int | None = None
    ) -> str:
        """Format retrieved chunks into context string for LLM"""
        cfg = get_settings()
        max_chars = max_chars if max_chars is not None else cfg.rag_max_context_chars
        context_parts = []
        total_chars = 0
        for i, r in enumerate(results):
            source = r.get("source", "Unknown")
            # Localize so the LLM sees Russian terms (not raw Latin INNs from JSON)
            conditions = [ru_localize(c) for c in (r.get("conditions") or [])]
            content = ru_localize(r.get("content", ""))
            score = r.get("score", 0)
            chunk_type = r.get("chunk_type", "general")

            # Build metadata line — include paper citation if available
            meta = f"[Source {i+1}: {source} | "
            if conditions:
                meta += f"Conditions: {', '.join(conditions)} | "
            else:
                meta += "Conditions: general | "
            meta += f"Relevance: {score:.2f}"

            # Add academic paper citation details
            if chunk_type == "academic_paper":
                paper_title = r.get("paper_title", "")
                paper_journal = r.get("paper_journal", "")
                paper_year = r.get("paper_year", "")
                paper_doi = r.get("paper_doi", "")
                citation_parts = []
                if paper_title:
                    citation_parts.append(f"Title: {paper_title}")
                if paper_journal:
                    citation_parts.append(f"Journal: {paper_journal}")
                if paper_year:
                    citation_parts.append(f"Year: {paper_year}")
                if paper_doi:
                    citation_parts.append(f"DOI: {paper_doi}")
                if citation_parts:
                    meta += f" | {'; '.join(citation_parts)}"

            meta += "]"

            part = f"{meta}\n{content}\n"
            if total_chars + len(part) > max_chars:
                remaining = max_chars - total_chars
                if remaining > 100:
                    context_parts.append(part[:remaining] + "...")
                break
            context_parts.append(part)
            total_chars += len(part)
        return "\n".join(context_parts)

    def is_ready(self) -> bool:
        """Whether the index and vectorizer are loaded and usable."""
        return self.index is not None and self.vectorizer is not None
