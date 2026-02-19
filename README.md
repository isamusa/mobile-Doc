
# 🏥 Mobile Doc: Context-Aware AI Primary Care for Rural Nigeria

![Mobile Doc](https://github.com/user-attachments/assets/b4038639-1bd0-4f39-977e-f00a2fa8f586)


> **Bridging the African healthcare gap with a secure, multimodal edge-AI assistant that sees, listens, and understands the Nigerian context.**

[![Built with Flutter](https://img.shields.io/badge/Built_with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Powered by Google Gemma](https://img.shields.io/badge/Powered_by-Gemma_2_%7C_Med--Gemma-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/gemma)
[![Backend FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)

---

## 🎬 Project Demo
**[🎥 Watch the 5-Minute Pitch & Technical Walkthrough on YouTube](YOUTUBE_LINK)**

---

## 🌍 The Challenge: A Crisis of Access
In Nigeria, the healthcare system faces a critical workforce deficit with a doctor-to-patient ratio of roughly **1:5,000**. 
* **The Waiting Game:** Rural patients travel long distances and wait 6–8 hours just to see a doctor for five minutes.
* **The "Black Box" of Diagnostics:** Patients receive complex paper lab reports (Widal, Malaria Parasite) filled with unintelligible medical jargon, leading to anxiety and dangerous self-medication.
* **The Dietary Blind Spot:** Chronic lifestyle diseases (Hypertension, Ulcers) are rising, but patients lack accessible, real-time guidance on whether local cuisine (e.g., *Fried Yam*, *Suya*) is safe for their specific condition.

## 💡 The Solution: Mobile Doc
Mobile Doc is a secure, Multimodal AI Medical Assistant designed to act as the "First Point of Contact." By leveraging Google's **Gemma 2** and **Med-Gemma**, we provide professional-grade triage, result interpretation, and lifestyle management directly on a mobile device.

| Context-Aware Chat | Multimodal Diagnostics | Edge-Optimized AI |
| :---: | :---: | :---: |
| ![Chat](https://github.com/user-attachments/assets/2e721af5-c9be-4051-99c7-74e475459768) | ![Vision](https://github.com/user-attachments/assets/6f8f41fb-1e6f-43c5-99d3-ee0f062ebc01) | ![Edge AI](https://github.com/user-attachments/assets/aed0d217-e757-434c-8085-9f00097849d1) |
| Remembers patient history, understands local context, and prevents hallucinations. | Instantly decodes complex Widal tests and triages X-ray pathologies. | Runs dual 4B and 2B models simultaneously via 4-bit quantization. |

---

## ⚙️ Technical Architecture (The "Secret Sauce")

Running heavy AI models on limited hardware to simulate cost-effective edge deployment was our biggest challenge. We architected a specialized **Hybrid AI Pipeline**.

1. **The Dual-Model Engine:** * **Chat Agent:** `google/gemma-2-2b-it` (Optimized for medical reasoning & empathic dialogue).
   * **Vision Agent:** `google/medgemma-1.5-4b-it` (Fine-tuned for biomedical tasks, radiology, and OCR).
2. **Memory Tetris (4-Bit Quantization):** We aggressively compressed both models using `BitsAndBytes` (NF4). This allowed us to load **both** models simultaneously into a single NVIDIA T4 GPU (16GB VRAM) at startup, eliminating the crash-prone "model swapping" latency.
3. **Intent Classifier & Context Injector:** Before the AI generates a single token, our backend seamlessly decrypts the patient's medical profile (Age, Genotype, Chronic Conditions like Ulcers) and appends it to the system prompt.

---

## 🔬 Under the Hood: Real-Time Inference Logs
*Because video compression can make terminal logs hard to read, here is the raw proof of our dual-model handover.*

### Scenario 1: The Emergency Handoff (Hemothorax)
*The Vision model detects internal bleeding. The Chat model receives this data, cross-references the patient's identity, and instantly shifts from casual conversation to an emergency protocol.*

```text
==================================================
📸 DEBUG - VISION CONTEXT (Med-Gemma 1.5 4B):
Mode: scan | Text: Medical Scan. (PATIENT SUMMARY: Name: John Doe...)
==================================================
👁️ DEBUG - VISION REPLY:
Findings: Right Hemothorax. There is a significant right-sided pleural effusion, likely a hemothorax given the context of potential trauma...

==================================================
🗣️ DEBUG - CONTEXT AWARE INPUT (Gemma 2 2B):
👉 LATEST: I've scanned a medical scan. The analysis says: "[Vision Output]". Based on my medical history, what are the next steps?
==================================================
🩺 DEBUG - AI REPLY:
Sannu, John. Based on the scan, you have a right hemothorax. This is a serious condition, so we need to act quickly.  
1. Go to the nearest hospital immediately. This is a medical emergency. 
2. Inform the doctors of your recent scan results. 
I'm here to support you, John. Stay strong!

```

### Scenario 2: Dietary Memory & Cultural Context

*The AI analyzes a local Nigerian dish. It actively checks the patient's decrypted profile, remembers they have an Ulcer, and warns them against the food.*

```text
==================================================
📸 DEBUG - VISION CONTEXT (Med-Gemma 1.5 4B):
Mode: diet | Text: fried yam and stew. (PATIENT SUMMARY: Conditions: Hypertension, Ulcer)
==================================================
👁️ DEBUG - VISION REPLY:
Verdict: Given the patient's history of hypertension and ulcer, this meal is potentially unsafe.
Recommendation: A lighter Nigerian alternative is recommended. Suggestion: Try Pap/Akamu, Pepper Soup, or Moi-moi.

==================================================
🗣️ DEBUG - CONTEXT AWARE INPUT (Gemma 2 2B):
👉 LATEST: I've scanned a meal (fried yam and stew). The analysis says: "[Vision Output]". Based on my medical history, what are the next steps?
==================================================
🩺 DEBUG - AI REPLY:
Sannu, John. I understand you've had fried yam and stew. Since you have an ulcer, it's best to break your fast gently with something light. How about a Pap or Akamu?

```

---

## 🚀 Getting Started (Local Development)

### 1. Flutter Frontend

```bash
git clone [https://github.com/isamusa/mobile-doc.git](https://github.com/isamusa/mobile-doc.git)
cd mobile-doc
flutter pub get
flutter run

```

### 2. FastAPI Inference Backend

To run the dual-model backend, you will need a GPU with at least 16GB of VRAM (e.g., Kaggle T4, Google Colab, or local).

1. Open the [Backend Inference Engine Notebook](https://www.kaggle.com/code/isamusa/mobile-doc-backend).
2. Add your `HF_TOKEN` and `NGROK_TOKEN` to Kaggle Secrets.
3. Run the notebook to expose the secure Ngrok tunnel.
4. Update the `STATIC_DOMAIN` in your Flutter app's `api_service.dart`.

---

## 👨‍💻 Built By

**Isa Usman** *Full-Stack Software Developer & Entrepreneur based in Jos, Nigeria.* Passionate about leveraging edge AI and mobile tech to build resilient digital infrastructure across Sub-Saharan Africa.

---

*Submitted for the Google / Kaggle Med-Gemma Impact Challenge (Main Track & Agentic Workflow Special Award).*
