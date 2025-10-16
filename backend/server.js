// server.js
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import OpenAI from 'openai';

const app = express();
app.use(express.json());

// при желании ограничь фронтовые origin'ы
app.use(cors({ origin: [/^http:\/\/localhost:\d+$/, /your-domain\.com$/] }));

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// healthcheck
app.get('/health', (_req, res) => res.send('ok'));

// простой чат-эндпоинт
app.post('/api/chat', async (req, res) => {
  try {
    const { messages, system } = req.body ?? {};
    // messages — массив {role:'user'|'assistant', content:'...'}
    // system — опционально: системная инструкция

    const response = await openai.responses.create({
      model: 'gpt-4o-mini',               // быстрый и недорогой
      input: [
        ...(system ? [{ role: 'system', content: system }] : []),
        ...(messages ?? [])
      ],
      // можно добавить: temperature: 0.7,
    });

    // В Responses API текст лежит в response.output_text
    // (а ещё можно детально разобрать response.output[0].content[0].text)
    const text = response.output_text ?? '';
    res.json({ text });
  } catch (err) {
    console.error('OpenAI error:', err?.message || err);
    res.status(500).json({ error: 'OpenAI request failed' });
  }
});

const PORT = process.env.PORT || 8787;
app.listen(PORT, () => {
  const mask = (k) => (k ? `${k.slice(0,3)}…${k.slice(-4)}` : 'missing');
  console.log('OPENAI_KEY starts with:', mask(process.env.OPENAI_API_KEY));
  console.log(`Server started on ${PORT}`);
});
