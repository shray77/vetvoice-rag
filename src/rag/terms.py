"""VetVoice RAG — RU↔EN словари медицинских терминов и перевод запросов.

Лёгкий модуль без ML-зависимостей (faiss/sklearn не нужны — только stdlib
`re`). Вынесен из retriever.py (Task 184), чтобы словарные тесты
(tests/test_terms.py) и перевод запросов можно было запускать без
тяжёлого ML-окружения. Историческое место определений — src/rag/retriever.py,
оттуда имена реэкспортируются для обратной совместимости.
"""

import re

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
    "levamisole": "левамизол",
    "clorsulon": "клорсулон",
    "toltrazuril": "толтразурил",
    "diclazuril": "диклазурил",
    "ponazuril": "поназурил",
    "marbofloxacin": "марбофлоксацин",
    "pradofloxacin": "прадофлоксацин",
    "gatifloxacin": "гатифлоксацин",
    "ciprofloxacin": "ципрофлоксацин",
    "levofloxacin": "левофлоксацин",
    "azithromycin": "азитромицин",
    "clarithromycin": "кларитромицин",
    "erythromycin": "эритромицин",
    "metoclopramide": "метоклопрамид",
    "ondansetron": "ондансетрон",
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
    "benazepril": "беназеприл",
    "enalapril": "эналаприл",
    "pimobendan": "пимобендан",
    "atenolol": "атенолол",
    "diltiazem": "дилтиазем",
    "amlodipine": "амлодипин",
    "lidocaine": "лидокаин",
    "procainamide": "прокаинамид",
    "sotalol": "соталол",
    "tetracycline": "тетрациклин",
    "amikacin": "амикацин",
    "tobramycin": "тобрамицин",
    "streptomycin": "стрептомицин",
}

# Reverse map for localizing LLM output: English/Latin term -> Russian.
# Used by ru_localize() to strip English drug/disease names that leak from RAG
# context (JSON `conditions`/`INN` fields) into the model's Russian answer.
_RU_LOCALIZE_MAP = {k.lower(): v for k, v in EN_RU_DRUG_TERMS.items()}

# Symptom / body-part fragments (substring match, lowercased). Used as a ROUTING
# signal: only symptom queries fuse in the disease sub-index. Drug/protocol/
# antidote queries that contain no symptom word stay on the main index, so the
# disease index can't displace their top result. Deliberately excludes disease
# NAMES and protocol words — those already work via the main index's condition
# keyword-boost, and routing them away would misfire on drug queries.
DISEASE_ROUTE_SYMPTOM_KEYS = {
    "чеш", "зуд", "чеса", "красн", "корк", "гно", "шерст", "лысе", "алопеци",
    "пятн", "перхот", "пузыр", "язв", "лиж", "воспал", "шелуш", "бляш", "узел",
    "опухол", "запах", "себоре", "пигмент", "эксуд", "мокнущ", "складк", "мокн",
    "лап", "морд", "уш", "живот", "спин", "груд", "пах", "нос", "глаз", "хвост",
    "сып",
}


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
