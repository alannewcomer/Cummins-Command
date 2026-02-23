'use strict';

const { GoogleGenAI } = require('@google/genai');

// Initialise once — API key from Cloud Functions environment config
let _client;
function client() {
  if (!_client) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error('GEMINI_API_KEY not set in environment');
    _client = new GoogleGenAI({ apiKey });
  }
  return _client;
}

/**
 * Call Gemini 2.5 Pro and parse a JSON response.
 *
 * @param {string} prompt  Full prompt text (system + user context)
 * @param {'low'|'medium'|'high'} _priority  Unused today, reserved for
 *   future rate-limit / queue prioritisation.
 * @returns {Promise<Object>} Parsed JSON from Gemini
 */
async function callGeminiPro(prompt, _priority = 'low') {
  const response = await client().models.generateContent({
    model: 'gemini-2.5-pro',
    contents: prompt,
    config: {
      responseMimeType: 'application/json',
      temperature: 0.3,
    },
  });

  const text = response.text ?? '';
  try {
    return JSON.parse(text);
  } catch {
    console.warn('Gemini Pro response was not valid JSON, wrapping:', text.slice(0, 200));
    return { raw: text };
  }
}

/**
 * Call Gemini 2.5 Flash for lighter/cheaper workloads.
 *
 * @param {string} prompt
 * @param {number} maxOutputTokens
 * @returns {Promise<Object>} Parsed JSON from Gemini
 */
async function callGeminiFlash(prompt, maxOutputTokens = 2048) {
  const response = await client().models.generateContent({
    model: 'gemini-2.5-flash',
    contents: prompt,
    config: {
      responseMimeType: 'application/json',
      temperature: 0.2,
      maxOutputTokens,
    },
  });

  const text = response.text ?? '';
  try {
    return JSON.parse(text);
  } catch {
    console.warn('Gemini Flash response was not valid JSON, wrapping:', text.slice(0, 200));
    return { raw: text };
  }
}

module.exports = { callGeminiPro, callGeminiFlash };
