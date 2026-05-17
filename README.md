# eatAI
**eatAI** is an automated fitness and macronutrient tracking solution. It leverages a hybrid architecture combining a local computer vision model with a live public nutrition database to eliminate manual food logging. Users simply capture a photo of a single food item, and the system automatically identifies the object, retrieves its real-world nutritional metrics, and updates the user's daily progress metrics.


## Architecture:
The system is split into a cross-platform mobile client and a high-performance Node.js backend.
*   **Mobile Client (Flutter / Dart):** Provides a dark-themed user interface focused on high scannability. Integrates camera hardware utilizing `image_picker` with strict size, aspect ratio, and compression constraints (`378x378`, 80% quality) to optimize network payloads. Features real-time linear progress tracking for daily caloric intake and protein synthesis targets.
*   **Analytical Backend (Node.js / Express):** Utilizes a local instance of `Ollama` running the `moondream` vision language model. The model is explicitly prompted to operate with `0.0 temperature` to ensure deterministic keyword extraction while ignoring environment artifacts (e.g., computer screens, desks). 
*   **Data Validation:** Tokenizes the AI-generated string and queries the **Open Food Facts API**. It maps the unstructured image data into real-world, verified nutrition objects, handles fallback conditions for unrecognized objects, and calculates weight-adjusted caloric distributions.

## Capabilities:
*   **Background Isolation:** The vision pipeline actively filters out ambient workplace or kitchen environments to lock onto the central dish.
*   **Live Database Integrity:** Rejects arbitrary AI hallucinations of caloric values by forcing data validation against a global open-source food database.
*   **Asynchronous Serialization:** Multi-part stream handling securely processes image payloads up to 5MB, featuring safe fallback defaults for custom portion estimations.

## Technologies:
| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | Flutter / Dart | Native rendering, multi-platform UI, and camera lifecycle management. |
| **Backend** | Node.js / Express | REST API endpoint routing, request timeouts, and data aggregation. |
| **Vision AI** | Ollama (`moondream`) | Local, lightweight vision-language model for strict keyword extraction. |
| **Database Access** | Open Food Facts API | Live REST query engine for localized German and global food facts. |
| **Middleware** | Multer | Express middleware for parsing multi-part form data and image buffer allocation. |

## API
### Scan Image
*   **Endpoint:** `POST /api/scan`
*   **Payload Type:** `multipart/form-data`
*   **Parameters:** `image` (File binary)

#### Sample Success Response (`200 OK`)
```json
{
  "gericht_name": "Coca-Cola Zero / Pizza Margherita",
  "gesamt_kalorien": 850,
  "proteine_g": 32,
  "kohlenhydrate_g": 110,
  "fette_g": 28,
  "zutaten": [
    {
      "name": "Pizza Margherita",
      "gewicht_g": 350,
      "kalorien": 850
    }
  ]
}
