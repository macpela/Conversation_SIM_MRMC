import time
import sounddevice as sd
import numpy as np
import queue
import re
import requests
import io
import wave
import threading
import pygame
import math
import random
from groq import Groq
from pythonosc import udp_client

# --- CONFIGURARE ---
GROQ_API_KEY = "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"
DEEPGRAM_API_KEY = "078df5ae6a23e8db154d5d428d9d66256f070493"
VOICE_MODEL = "aura-luna-en" 

client_osc = udp_client.SimpleUDPClient("127.0.0.1", 12000)

# AUDIO INIT
pygame.mixer.init(frequency=24000, buffer=1024)

def play_audio_fast(audio_data):
    try:
        if pygame.mixer.music.get_busy():
            pygame.mixer.music.stop()
        sound_file = io.BytesIO(audio_data)
        pygame.mixer.music.load(sound_file)
        pygame.mixer.music.play()
    except Exception as e:
        print(f"Audio Error: {e}")

# --- MOTOR FIZIC AVANSAT (GESTICULATOR) ---
class FlairEngine:
    def __init__(self):
        # Axe: Base, Lift, Arm, Pan, Tilt, Cart
        self.axes = [0.0] * 6 
        # Tinta de baza (setata de AI)
        self.base_target = [0.0, -0.2, 0.3, 0.0, -0.1, 0.8] 
        self.running = True
        
        # Offset-uri random ca sa nu arate toti robotii la fel
        self.offsets = [random.random() * 100 for _ in range(6)]
        
        threading.Thread(target=self.physics_loop, daemon=True).start()

    def set_ai_target(self, coords):
        if len(coords) == 6:
            print(f"🤖 NEW POSE: {coords}")
            self.base_target = coords

    def physics_loop(self):
        t = 0
        while self.running:
            t += 0.02
            
            # Verificam daca robotul vorbeste
            is_speaking = pygame.mixer.music.get_busy()
            
            # Copiem tinta de baza data de AI
            final_target = list(self.base_target)
            
            if is_speaking:
                # --- MODUL GESTICULARE (VORBIRE) ---
                # Aici adaugam miscare peste pozitia statica
                
                # 1. Capul (Pan/Tilt) - Se misca mai alert, ca si cum ar explica
                final_target[3] += math.sin(t * 2.5 + self.offsets[3]) * 0.15  # Pan stanga-dreapta
                final_target[4] += math.cos(t * 3.0 + self.offsets[4]) * 0.10  # Tilt sus-jos (accentuare)
                
                # 2. Bratul (Arm) - Gesticuleaza usor
                final_target[2] += math.sin(t * 1.5 + self.offsets[2]) * 0.10 
                
                # 3. Corpul (Lift/Base) - Se leagana pe ritm
                final_target[1] += math.sin(t * 1.0) * 0.05
                final_target[0] += math.sin(t * 0.5) * 0.05 # Rotatie lenta
                
            else:
                # --- MODUL IDLE (RESPIRATIE) ---
                # Miscare foarte lenta si subtila
                
                # Respiratie usoara pe Lift si Brat
                breath = math.sin(t * 1.0) * 0.02
                final_target[1] += breath 
                final_target[2] += breath * 0.5
                
                # Scanare foarte lenta a camerei cu capul
                if final_target[5] > 0.5: # Doar daca e departe
                    final_target[3] += math.sin(t * 0.2) * 0.05

            # --- INTERPOLARE (SMOOTHING) ---
            # Cat de repede ajunge la noua pozitie calculata
            # 0.05 = Mediu, 0.1 = Rapid, 0.02 = Greoi
            inertia = 0.05 
            
            for i in range(6):
                self.axes[i] += (final_target[i] - self.axes[i]) * inertia
            
            try: client_osc.send_message("/joints", self.axes)
            except: pass
            
            time.sleep(0.016) # ~60 FPS update rate

# --- CREIERUL (TITAN/LUNA) ---
class TitanBrain:
    def __init__(self):
        print(">>> INITIALIZING LUNA (FULL GESTURE ENGINE)...")
        self.groq = Groq(api_key=GROQ_API_KEY)
        self.flair = FlairEngine()
        self.q = queue.Queue()
        
        self.history = [
            {"role": "system", "content": """
             You are Luna, a girl who was raised by a romanian gispy family and you can predict the future. Language: English. Tone: Warm, natural.
             
             CRITICAL: You control a 6-AXIS ROBOTIC ARM.
             Append tag: <MOVE:Base,Lift,Arm,Pan,Tilt,Cart>
             (-1.0 to 1.0)
             
             Use distinct poses:
             - Confident: Lift high (0.5), Head Up (0.2).
             - Listening: Lean in (Cart -0.6), Head tilted (-0.2).
             - Thinking: Look away (Pan 0.4).
             
             Example: "I am listening." <MOVE:0.2,-0.3,0.5,-0.1,-0.2,-0.7>
             """}
        ]
        client_osc.send_message("/robot", "SYSTEM READY")

    def audio_callback(self, indata, frames, time, status):
        self.q.put(bytes(indata))

    def run(self):
        print(">>> LISTENING...")
        buffer = bytearray()
        silence_start = time.time()
        recording = False
        last_speech_time = 0 
        
        with sd.InputStream(callback=self.audio_callback, channels=1, samplerate=16000, dtype='int16'):
            while True:
                # 1. FIX PENTRU ECOU
                if pygame.mixer.music.get_busy():
                    client_osc.send_message("/status", "SPEAKING")
                    while not self.q.empty(): self.q.get() 
                    last_speech_time = time.time()
                    time.sleep(0.05)
                    continue

                # 2. COOL-DOWN
                if time.time() - last_speech_time < 0.5:
                    while not self.q.empty(): self.q.get()
                    time.sleep(0.01)
                    continue

                # 3. ASCULTARE
                while not self.q.empty():
                    data = self.q.get()
                    vol = np.linalg.norm(np.frombuffer(data, dtype=np.int16))
                    
                    if vol > 600: 
                        if not recording:
                            print(">>> Voice detected.")
                            client_osc.send_message("/status", "LISTENING")
                            recording = True
                            buffer = bytearray()
                        silence_start = time.time()
                    
                    if recording: buffer.extend(data)

                if recording and (time.time() - silence_start > 0.8):
                    recording = False
                    if len(buffer) > 4000:
                        threading.Thread(target=self.process, args=(bytes(buffer),)).start()
                    else:
                        client_osc.send_message("/status", "IDLE")
                    buffer = bytearray()

                time.sleep(0.01)

    def process(self, audio_bytes):
        client_osc.send_message("/status", "THINKING")
        client_osc.send_message("/robot", "...")
        try:
            # 1. STT
            byte_io = io.BytesIO()
            with wave.open(byte_io, 'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
                w.writeframes(audio_bytes)
            wav_data = byte_io.getvalue()

            url = "https://api.deepgram.com/v1/listen?model=nova-2&language=en&smart_format=true"
            headers = {"Authorization": f"Token {DEEPGRAM_API_KEY}", "Content-Type": "audio/wav"}
            r = requests.post(url, headers=headers, data=wav_data)
            txt = r.json().get('results', {}).get('channels', [{}])[0].get('alternatives', [{}])[0].get('transcript', '')
            
            if len(txt) < 2: return

            print(f"You: {txt}")
            client_osc.send_message("/text", f"You: {txt}")
            self.history.append({"role": "user", "content": txt})
            
            # 2. LLM
            chat = self.groq.chat.completions.create(messages=self.history, model="llama-3.3-70b-versatile", max_tokens=150)
            reply = chat.choices[0].message.content
            
            # --- FIX PENTRU TAG-URI MULTIPLE ---
            
            # Pas 1: Gasim toate miscarile din text
            moves = re.findall(r'<MOVE:(.*?)>', reply)
            if moves:
                # O luam pe ultima (cea mai recenta stare)
                last_move = moves[-1] 
                try:
                    coords = [float(x) for x in last_move.split(',')]
                    self.flair.set_ai_target(coords) 
                except: pass
            
            # Pas 2: Stergem TOATE tag-urile din text folosind Regex (re.sub)
            # Asta garanteaza ca textul ramane curat pentru TTS
            clean_reply = re.sub(r'<MOVE:.*?>', '', reply).strip()
            
            # Pas 3: Curatam spatiile duble ramase in urma stergerii
            clean_reply = re.sub(r'\s+', ' ', clean_reply)

            # -----------------------------------
            
            print(f"Luna: {clean_reply}")
            client_osc.send_message("/text", clean_reply)
            self.history.append({"role": "assistant", "content": reply})
            
            # 4. TTS
            tts_url = f"https://api.deepgram.com/v1/speak?model={VOICE_MODEL}"
            tts_h = {"Authorization": f"Token {DEEPGRAM_API_KEY}", "Content-Type": "application/json"}
            tts_r = requests.post(tts_url, headers=tts_h, json={"text": clean_reply})
            
            if tts_r.status_code == 200:
                play_audio_fast(tts_r.content)
            
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    bot = TitanBrain()
    bot.run()