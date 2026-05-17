const express = require('express');
const cors = require('cors');
const multer = require('multer');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));

const storage = multer.memoryStorage();
const upload = multer({ 
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 } 
});

const OLLAMA_API_URL = 'http://127.0.0.1:11434/api/generate';

async function fetchProductMacros(keyword) {
    try {
        const url = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(keyword)}&search_simple=1&action=process&json=1&page_size=1`;
        
        // PUBLIC TEMPLATE: Complies with Open Food Facts Usage Policy.
        // If you fork this repository, please change 'OpenSource-Scanner-Dev' to your own project identifier.
        const res = await fetch(url, { 
            headers: { 'User-Agent': 'OpenSource-Scanner-Dev/1.0.0 (Generic Educational Client)' } 
        });
        
        if (!res.ok) return null;
        const data = await res.json();
        
        if (!data.products || data.products.length === 0) return null;
        const product = data.products[0];
        const macros = product.nutriments;

        let defaultWeight = 150;
        if (keyword.includes('water') || keyword.includes('drink') || keyword.includes('soda')) defaultWeight = 500;
        if (keyword.includes('pizza') || keyword.includes('burger')) defaultWeight = 350;

        return {
            name: product.product_name_en || product.product_name || keyword,
            weight: defaultWeight,
            caloriesPer100g: parseFloat(macros['energy-kcal_100g'] || macros['energy_100g'] / 4.184 || 0),
            proteinPer100g: parseFloat(macros['proteins_100g'] || 0),
            carbsPer100g: parseFloat(macros['carbohydrates_100g'] || 0),
            fatPer100g: parseFloat(macros['fat_100g'] || 0)
        };
    } catch (e) {
        console.error(`Error during API request for ${keyword}:`, e);
        return null;
    }
}

app.post('/api/scan', upload.single('image'), async (req, res) => {
    req.setTimeout(120000); 

    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No image uploaded.' });
        }

        const base64Image = req.file.buffer.toString('base64');
        console.log(`[${new Date().toLocaleTimeString()}] Image received. Starting fast keyword scan...`);

        const response = await fetch(OLLAMA_API_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                model: 'moondream',
                prompt: "Focus ONLY on the main food item or grocery pack placed directly in the foreground center of the image. Completely IGNORE the background, computer screens, keyboards, monitors, or desks. Output ONLY the single main food name as a keyword, nothing else.",
                stream: false,
                options: { temperature: 0.0 } 
            })
        });

        if (!response.ok) throw new Error(`Ollama Error: ${response.statusText}`);
        const data = await response.json();
        const rawKeywords = data.response.toLowerCase().trim().replace('.', '');
        console.log("Detected Keywords:", rawKeywords);

        const keywordsArray = rawKeywords.split(',').map(k => k.trim()).filter(k => k.length > 1);

        let finalResponse = {
            "dish_name": "Scan Result",
            "total_calories": 0,
            "protein_g": 0,
            "carbs_g": 0,
            "fat_g": 0,
            "ingredients": []
        };

        for (const keyword of keywordsArray) {
            console.log(`Searching nutrition values for: ${keyword}...`);
            const targetData = await fetchProductMacros(keyword);
            
            if (targetData) {
                const factor = targetData.weight / 100;
                const itemCalories = Math.round(targetData.caloriesPer100g * factor);

                finalResponse.ingredients.push({
                    "name": targetData.name,
                    "weight_g": targetData.weight,
                    "calories": itemCalories
                });

                finalResponse.total_calories += itemCalories;
                finalResponse.protein_g += Math.round(targetData.proteinPer100g * factor);
                finalResponse.carbs_g += Math.round(targetData.carbsPer100g * factor);
                finalResponse.fat_g += Math.round(targetData.fatPer100g * factor);
            }
        }

        if (finalResponse.ingredients.length === 0) {
            finalResponse.dish_name = "Undetected Plate";
            finalResponse.ingredients.push({ "name": "Scanned Object (No Data found)", "weight_g": 100, "calories": 0 });
        } else {
            finalResponse.dish_name = finalResponse.ingredients.map(i => i.name).join(" + ");
        }

        console.log("Sending completed data packet to app:", finalResponse);
        return res.json(finalResponse);

    } catch (error) {
        console.error('Server Error:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`eatAI Hybrid Server is running on port ${PORT}`);
});
