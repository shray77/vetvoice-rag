"""VetVoice RAG Retriever — FAISS + TF-IDF retrieval for veterinary dermatology"""

import os
import json
import pickle
import re
from typing import List, Dict
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import normalize
import faiss

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


def translate_ru_to_en_query(text: str) -> str:
    """Translate Russian medical query to English for FAISS retrieval"""
    text_lower = text.lower()
    en_terms = []
    sorted_terms = sorted(RU_EN_TERMS.items(), key=lambda x: len(x[0]), reverse=True)
    for ru_term, en_translation in sorted_terms:
        if ru_term in text_lower:
            en_terms.append(en_translation)
    en_words = re.findall(r'[a-zA-Z]+', text)
    parts = [text]
    if en_terms:
        parts.append(" ".join(en_terms))
    if en_words:
        parts.append(" ".join(en_words))
    return " ".join(parts)


class VetDermRAG:
    """Retrieval-Augmented Generation for Veterinary Dermatology"""

    def __init__(self, repo_id: str = "shrayyyy/vet-derm-rag", local_dir: str = "/tmp/vet_rag"):
        self.repo_id = repo_id
        self.local_dir = local_dir
        self.index = None
        self.vectorizer = None
        self.documents = []
        self._load()

    def _load(self):
        """Load FAISS index, vectorizer, and documents from HF Hub"""
        from huggingface_hub import hf_hub_download

        os.makedirs(self.local_dir, exist_ok=True)
        token = os.environ.get("HF_TOKEN", "")

        index_path = hf_hub_download(
            repo_id=self.repo_id, filename="vet_derm_faiss.index",
            token=token, local_dir=self.local_dir
        )
        vec_path = hf_hub_download(
            repo_id=self.repo_id, filename="vet_derm_vectorizer.pkl",
            token=token, local_dir=self.local_dir
        )
        doc_path = hf_hub_download(
            repo_id=self.repo_id, filename="vet_derm_retrieval_store.json",
            token=token, local_dir=self.local_dir
        )

        self.index = faiss.read_index(index_path)
        with open(vec_path, 'rb') as f:
            self.vectorizer = pickle.load(f)
        with open(doc_path, 'r', encoding='utf-8') as f:
            self.documents = json.load(f)

        print(f"RAG loaded: {self.index.ntotal} vectors, {len(self.documents)} docs")

    def retrieve(self, query: str, top_k: int = 5) -> List[Dict]:
        """Retrieve relevant knowledge chunks for a query"""
        search_query = translate_ru_to_en_query(query)
        query_vec = self.vectorizer.transform([search_query]).toarray().astype('float32')
        query_vec = normalize(query_vec, norm='l2')
        distances, indices = self.index.search(query_vec, top_k)

        results = []
        for dist, idx in zip(distances[0], indices[0]):
            if idx < len(self.documents) and dist > 0.01:
                doc = self.documents[idx].copy()
                doc["score"] = float(dist)
                results.append(doc)
        return results

    def format_context(self, results: List[Dict], max_chars: int = 5000) -> str:
        """Format retrieved chunks into context string for LLM"""
        context_parts = []
        total_chars = 0
        for i, r in enumerate(results):
            source = r.get("source", "Unknown")
            conditions = r.get("conditions", [])
            content = r.get("content", "")
            score = r.get("score", 0)
            part = (
                f"[Source {i+1}: {source} | "
                f"Conditions: {', '.join(conditions) if conditions else 'general'} | "
                f"Relevance: {score:.2f}]\n{content}\n"
            )
            if total_chars + len(part) > max_chars:
                remaining = max_chars - total_chars
                if remaining > 100:
                    context_parts.append(part[:remaining] + "...")
                break
            context_parts.append(part)
            total_chars += len(part)
        return "\n".join(context_parts)
