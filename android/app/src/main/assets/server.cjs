var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// server.ts
var import_express = __toESM(require("express"), 1);
var import_path = __toESM(require("path"), 1);
var import_vite = require("vite");
var import_genai = require("@google/genai");
var import_dotenv = __toESM(require("dotenv"), 1);
import_dotenv.default.config();
var app = (0, import_express.default)();
var PORT = 3e3;
app.use(import_express.default.json({ limit: "20mb" }));
app.use(import_express.default.urlencoded({ limit: "20mb", extended: true }));
var apiKey = process.env.GEMINI_API_KEY;
var ai = null;
if (apiKey && apiKey !== "MY_GEMINI_API_KEY") {
  ai = new import_genai.GoogleGenAI({
    apiKey,
    httpOptions: {
      headers: {
        "User-Agent": "aistudio-build"
      }
    }
  });
}
app.post("/api/scan", async (req, res) => {
  try {
    const { image } = req.body;
    if (!image) {
      res.status(400).json({ error: "No image data provided" });
      return;
    }
    if (!ai) {
      res.status(500).json({
        error: "Gemini API client not initialized. Please ensure the GEMINI_API_KEY is configured in your Secrets panel."
      });
      return;
    }
    const base64Data = image.replace(/^data:image\/\w+;base64,/, "");
    const promptText = `
      You are a specialized grading sheet optical reader. Analyze the provided image of a grading sheet section.
      The image contains three key components in sequence:
      1. A printed subject code (\u0643\u0648\u062F \u0627\u0644\u0645\u0627\u062F\u0629) - typically an integer printed from 1 to 15.
      2. A QR Code or barcode containing the student's secret code (\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0633\u0631\u064A).
      3. A handwritten grade (\u0627\u0644\u062F\u0631\u062C\u0629 \u0627\u0644\u0645\u0643\u062A\u0648\u0628\u0629 \u0628\u062E\u0637 \u0627\u0644\u064A\u062F). The grade can be written in Eastern Arabic (Hindi) numerals (e.g., \u0660, \u0661, \u0662, \u0663, \u0664, \u0665, \u0666, \u0667, \u0668, \u0669) or Western Arabic numerals (e.g., 0 to 100, potentially with decimals like 15.5 or half marks).

      Identify these values accurately:
      - printedSubjectCode: Look for the printed number representing the subject code (integer from 1 to 15).
      - qrCode: Read the QR Code content. If you can read it, return its exact alphanumeric content. If the QR code is clearly visible, extract its text.
      - handwrittenGrade: Read the handwritten score. Translate any Eastern Arabic/Hindi numerals (like \u0661\u0665) to Western standard numerals (like "15"). Return it as a string representing the grade (e.g., "17.5" or "20").

      Provide your confidence level for each field as well. If a field is not detected or is completely unreadable, return null for its value.
    `;
    const imagePart = {
      inlineData: {
        mimeType: "image/jpeg",
        data: base64Data
      }
    };
    const textPart = {
      text: promptText
    };
    const runGenerationForModel = async (modelName) => {
      return await ai.models.generateContent({
        model: modelName,
        contents: { parts: [imagePart, textPart] },
        config: {
          responseMimeType: "application/json",
          responseSchema: {
            type: import_genai.Type.OBJECT,
            properties: {
              printedSubjectCode: {
                type: import_genai.Type.INTEGER,
                description: "The printed subject code detected (integer 1 to 15), or null if not detected."
              },
              qrCode: {
                type: import_genai.Type.STRING,
                description: "The string text scanned from the QR code, or null if not detected."
              },
              handwrittenGrade: {
                type: import_genai.Type.STRING,
                description: "The handwritten grade/score translated to a Western numeral string (e.g., '14.5' or '18'), or null if not detected."
              },
              subjectCodeConfidence: {
                type: import_genai.Type.NUMBER,
                description: "Confidence from 0.0 to 1.0."
              },
              qrCodeConfidence: {
                type: import_genai.Type.NUMBER,
                description: "Confidence from 0.0 to 1.0."
              },
              gradeConfidence: {
                type: import_genai.Type.NUMBER,
                description: "Confidence from 0.0 to 1.0."
              }
            },
            required: ["printedSubjectCode", "qrCode", "handwrittenGrade"]
          }
        }
      });
    };
    const retryWithBackoff = async (fn, modelName, retries = 2, delay = 1e3) => {
      try {
        return await fn();
      } catch (err) {
        const errorMsg = err?.message || "";
        const isTransient = err?.status === 503 || err?.code === 503 || err?.statusCode === 503 || err?.status === 429 || err?.code === 429 || err?.statusCode === 429 || errorMsg.includes("503") || errorMsg.toLowerCase().includes("high demand") || errorMsg.toLowerCase().includes("unavailable") || errorMsg.toLowerCase().includes("temporary") || errorMsg.toLowerCase().includes("resource exhausted") || errorMsg.toLowerCase().includes("rate limit") || errorMsg.toLowerCase().includes("quota");
        if (retries > 0 && isTransient) {
          console.warn(`[Gemini API] Model ${modelName} is busy/exhausted (503/429). Retrying in ${delay}ms... (${retries} attempts remaining)`);
          await new Promise((resolve) => setTimeout(resolve, delay));
          return retryWithBackoff(fn, modelName, retries - 1, delay * 1.5);
        }
        throw err;
      }
    };
    const modelsToTry = [
      "gemini-3.5-flash",
      "gemini-flash-latest",
      "gemini-3.1-flash-lite"
    ];
    let lastError = null;
    let response = null;
    for (const model of modelsToTry) {
      try {
        console.log(`[Gemini API] Attempting scan using model: ${model}`);
        response = await retryWithBackoff(() => runGenerationForModel(model), model, 2, 1200);
        console.log(`[Gemini API] Scan successful using model: ${model}`);
        break;
      } catch (err) {
        lastError = err;
        console.warn(`[Gemini API] Model ${model} failed: ${err.message || err}. Trying next model...`);
      }
    }
    if (!response) {
      throw lastError || new Error("All candidate models failed to process the scanning request.");
    }
    const resultText = response.text;
    if (!resultText) {
      throw new Error("Empty response from Gemini API");
    }
    const parsedResult = JSON.parse(resultText);
    res.json({ success: true, result: parsedResult });
  } catch (error) {
    console.error("Scanning Error:", error);
    res.status(500).json({ success: false, error: error.message || "An error occurred during scanning" });
  }
});
async function startServer() {
  if (process.env.NODE_ENV !== "production") {
    const vite = await (0, import_vite.createServer)({
      server: { middlewareMode: true },
      appType: "spa"
    });
    app.use(vite.middlewares);
  } else {
    const distPath = import_path.default.join(process.cwd(), "dist");
    app.use(import_express.default.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(import_path.default.join(distPath, "index.html"));
    });
  }
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}
startServer();
//# sourceMappingURL=server.cjs.map
