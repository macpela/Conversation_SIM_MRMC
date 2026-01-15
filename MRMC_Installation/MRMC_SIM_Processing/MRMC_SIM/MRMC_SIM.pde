/* TITAN ULTIMATE: INDUSTRIAL CONFESSOR VOID
   Architecture: Object Oriented / High Fidelity
   Visual Style: MRMC Modula / Black Mirror Tech
   Control: External Python Brain via OSC
*/

import oscP5.*;
import netP5.*;
import java.util.LinkedList; // Pentru consola de log-uri

// --- GLOBAL SETTINGS ---
OscP5 oscP5;
RobotArm titan;
Environment stage;
Interface hud;
CinematicCam cam;

// Date partajate
float[] targetJoints = new float[6];
float[] currentJoints = new float[6];
String aiMessage = "SYSTEM INITIALIZED. WAITING FOR LINK...";
String aiStatus = "STANDBY";
int lastPacketTime = 0;

PFont fontTech, fontBold;

void setup() {
  size(1280, 720, P3D); // Full HD Window
  pixelDensity(2); // Retina display sharp
  smooth(8); // Anti-aliasing maxim
  frameRate(60);
  
  // OSC Setup
  oscP5 = new OscP5(this, 12000);
  
  // Fonts
  fontTech = createFont("Courier New", 12);
  fontBold = createFont("Arial Bold", 14);
  
  // Initialize Modules
  titan = new RobotArm();
  stage = new Environment();
  hud = new Interface();
  cam = new CinematicCam();
  
  // Init arrays
  for(int i=0; i<6; i++) {
    targetJoints[i] = 0;
    currentJoints[i] = 0;
  }
}

void draw() {
  // 1. UPDATE PHYSICS
  updatePhysics();
  cam.update();
  
  // 2. RENDER 3D SCENE
  background(15); // Deep Dark Grey
  
  // Setup Lighting
  stage.setLighting();
  
  // Apply Camera
  cam.apply();
  
  // Draw World
  stage.drawFloor();
  stage.drawAtmosphere();
  
  // Draw Robot
  titan.render();
  
  // 3. RENDER 2D UI (HUD)
  hud.render();
}

void updatePhysics() {
  // Interpolare fina pentru miscare organica
  // Diferite axe au inertie diferita (baza e grea, capul e usor)
  float[] inertias = {0.03, 0.04, 0.05, 0.08, 0.08, 0.04};
  
  for(int i=0; i<6; i++) {
    currentJoints[i] = lerp(currentJoints[i], targetJoints[i], inertias[i]);
  }
}

// ==========================================
// CLASS: ROBOT ARM (The Machine)
// ==========================================
class RobotArm {
  
  void render() {
    pushMatrix();
    
    // --- AXIS 5: CART (TRACK MOVEMENT) ---
    float trackPos = map(currentJoints[5], -1, 1, -400, 400);
    translate(trackPos, 0, 0);
    drawDolly();
    
    // --- AXIS 0: BASE (ROTATION) ---
    translate(0, -20, 0); // Putine peste dolly
    rotateY(currentJoints[0] * PI);
    drawBaseModule();
    
    // --- AXIS 1: SHOULDER (LIFT) ---
    // Un robot Modula nu face doar rotatie, ci si lift geometric
    translate(0, -60, 0);
    rotateX(map(currentJoints[1], -1, 1, -PI/4, PI/2));
    drawShoulderJoint();
    
    // --- ARM SEGMENT 1 ---
    translate(0, -140, 0);
    drawLowerArm();
    
    // --- AXIS 2: ELBOW ---
    translate(0, -120, 0);
    rotateX(map(currentJoints[2], -1, 1, -PI/1.2, PI/1.2));
    drawElbowJoint();
    
    // --- ARM SEGMENT 2 ---
    translate(0, -100, 0);
    drawUpperArm();
    
    // --- AXIS 3: PAN (HEAD ROTATION) ---
    translate(0, -80, 0);
    rotateY(currentJoints[3] * PI);
    drawNeck();
    
    // --- AXIS 4: TILT (HEAD NOD) ---
    translate(0, -20, 0);
    rotateX(currentJoints[4] * PI/2);
    drawHead();
    
    popMatrix();
  }
  
  // --- GEOMETRY HELPERS ---
  
  void drawDolly() {
    fill(40); stroke(60); strokeWeight(1);
    box(160, 20, 160); // Main Plate
    
    // Roti / Sine detalii
    fill(20); noStroke();
    pushMatrix(); translate(-70, 15, 60); box(20, 10, 180); popMatrix();
    pushMatrix(); translate(70, 15, 60); box(20, 10, 180); popMatrix();
  }
  
  void drawBaseModule() {
    // Industrial Chamfer Box
    fill(220); // Matte White/Grey
    noStroke();
    
    pushMatrix();
    translate(0, -40, 0);
    // Main housing
    box(90, 100, 90);
    
    // Detalii mecanice (Suruburi)
    fill(50);
    for(int i=0; i<4; i++) {
      pushMatrix();
      rotateY(HALF_PI * i);
      translate(35, 30, 46);
      ellipse(0,0, 5, 5);
      popMatrix();
    }
    popMatrix();
  }
  
  void drawShoulderJoint() {
    fill(60); // Dark Metal
    rotateZ(HALF_PI);
    drawCylinder(50, 100, 24);
    rotateZ(-HALF_PI);
    
    // Motor housing
    fill(30);
    pushMatrix(); translate(60, 0, 0); box(40, 60, 60); popMatrix();
  }
  
  void drawLowerArm() {
    fill(200); // White Plastic/Metal
    pushMatrix();
    translate(0, 60, 0); // Center adjustment
    box(60, 240, 50);
    
    // Branding Stripe
    fill(255, 100, 0); // Orange stripe
    translate(0, 0, 26);
    rect(-10, -100, 20, 200);
    popMatrix();
  }
  
  void drawElbowJoint() {
    fill(60); 
    rotateZ(HALF_PI);
    drawCylinder(45, 80, 24);
    rotateZ(-HALF_PI);
    
    // Cabluri simulate
    stroke(20); strokeWeight(3); noFill();
    bezier(30, 20, 0,  30, 50, 0,  30, -50, 0,  30, -20, 0);
    noStroke();
  }
  
  void drawUpperArm() {
    fill(210);
    pushMatrix();
    translate(0, 40, 0);
    box(45, 180, 45);
    popMatrix();
  }
  
  void drawNeck() {
    fill(40);
    box(50, 20, 50);
  }
  
  void drawHead() {
    // Design inspirat de camere de supraveghere high-end
    fill(20); // Black matte body
    box(60, 50, 90);
    
    // Front Lens Housing
    pushMatrix();
    translate(0, 0, 46);
    fill(10);
    drawCylinder(22, 5, 32); // Inel lentila
    
    // THE EYE (Lentila)
    translate(0, 0, 3);
    
    // Iris Pulse
    float pulse = 15 + sin(millis() * 0.002) * 2;
    fill(0, 200, 255); // Cyan Eye
    if(aiStatus.equals("LISTENING")) fill(0, 255, 100); // Green
    if(aiStatus.equals("THINKING")) fill(255, 200, 0); // Orange
    if(aiStatus.equals("SPEAKING")) fill(255, 50, 100); // Red/Pink
    
    emissive(100); // Sa straluceasca
    noStroke();
    ellipse(0, 0, pulse, pulse);
    emissive(0); // Reset emissive
    
    // Reflexie pe lentila (Fake)
    fill(255, 150);
    ellipse(5, -5, 5, 5);
    
    popMatrix();
  }
  
  // Custom Cylinder Helper
  void drawCylinder(float r, float h, int sides) {
    float angle = 360.0 / sides;
    beginShape(TRIANGLE_STRIP);
    for (int i = 0; i <= sides; i++) {
      float x = cos(radians(i * angle)) * r;
      float y = sin(radians(i * angle)) * r;
      vertex(x, y, -h/2);
      vertex(x, y, h/2);
    }
    endShape();
    
    // Caps
    fill(40);
    beginShape(TRIANGLE_FAN);
    vertex(0, 0, -h/2);
    for (int i = 0; i <= sides; i++) {
      float x = cos(radians(i * angle)) * r;
      float y = sin(radians(i * angle)) * r;
      vertex(x, y, -h/2);
    }
    endShape();
    
    beginShape(TRIANGLE_FAN);
    vertex(0, 0, h/2);
    for (int i = 0; i <= sides; i++) {
      float x = cos(radians(i * angle)) * r;
      float y = sin(radians(i * angle)) * r;
      vertex(x, y, h/2);
    }
    endShape();
  }
}

// ==========================================
// CLASS: ENVIRONMENT (Stage & Atmo)
// ==========================================
class Environment {
  ArrayList<PVector> dust;
  
  Environment() {
    dust = new ArrayList<PVector>();
    for(int i=0; i<100; i++) {
      dust.add(new PVector(random(-500, 500), random(-500, 0), random(-500, 500)));
    }
  }
  
  void setLighting() {
    // Dramatic Lighting Setup
    ambientLight(30, 35, 40); // Cold shadow
    
    // Key Light (Warm)
    directionalLight(255, 240, 200, 0.5, 0.8, -0.5);
    
    // Rim Light (Blue-ish) for tech feel
    spotLight(0, 100, 255, 0, -500, -500, 0, 1, 1, PI/2, 2);
    
    // Fill Light
    pointLight(50, 50, 60, 0, -200, 200);
  }
  
  void drawFloor() {
    pushMatrix();
    translate(0, 20, 0);
    
    // Track Rail
    fill(10); noStroke();
    box(1500, 10, 80);
    
    // Metal strips on track
    stroke(100); strokeWeight(2);
    line(-700, -6, -30, 700, -6, -30);
    line(-700, -6, 30, 700, -6, 30);
    
    // Floor Grid
    translate(0, 5, 0);
    rotateX(HALF_PI);
    fill(20); noStroke();
    rectMode(CENTER);
    rect(0, 0, 3000, 2000);
    
    stroke(255, 30); strokeWeight(1);
    for(int i = -1000; i < 1000; i+=100) {
      line(i, -1000, i, 1000);
      line(-1000, i, 1000, i);
    }
    popMatrix();
  }
  
  void drawAtmosphere() {
    // Floating Dust Particles
    stroke(255, 100);
    strokeWeight(2);
    for(PVector p : dust) {
      point(p.x, p.y, p.z);
      // Animate dust
      p.y -= 0.2;
      p.x += random(-0.1, 0.1);
      if(p.y < -600) p.y = 20;
    }
  }
}

// ==========================================
// CLASS: INTERFACE (HUD & Telemetry)
// ==========================================
class Interface {
  LinkedList<String> logs;
  
  Interface() {
    logs = new LinkedList<String>();
    addLog("BOOT SEQUENCE INITIATED");
    addLog("OSC LISTENER: PORT 12000");
    addLog("RENDERING ENGINE: P3D");
  }
  
  void addLog(String s) {
    logs.add(nf(hour(),2)+":"+nf(minute(),2)+":"+nf(second(),2) + " > " + s);
    if(logs.size() > 8) logs.removeFirst();
  }
  
  void render() {
    hint(DISABLE_DEPTH_TEST);
    camera(); // Reset camera for 2D overlay
    noLights();
    
    // --- TOP BAR ---
    fill(0, 200); noStroke();
    rect(0, 0, width, 60);
    
    fill(255); textFont(fontBold); textSize(16); textAlign(LEFT, CENTER);
    text("TITAN V.9 [INDUSTRIAL LINK]", 20, 30);
    
    // Status Indicator
    float w = textWidth("TITAN V.9 [INDUSTRIAL LINK]") + 40;
    fill(aiStatus.equals("LISTENING") ? #00FF00 : (aiStatus.equals("SPEAKING") ? #00FFFF : #555555));
    ellipse(w, 30, 10, 10);
    textSize(12); fill(150);
    text(aiStatus, w + 15, 30);
    
    // --- AXIS TELEMETRY (Right Side) ---
    drawTelemetry(width - 220, 100);
    
    // --- CONSOLE (Top Right) ---
    drawConsole(width - 320, 20);
    
    // --- SUBTITLES (Bottom) ---
    drawSubtitles();
    
    hint(ENABLE_DEPTH_TEST);
  }
  
  void drawTelemetry(float x, float y) {
    textFont(fontTech); textSize(10);
    String[] names = {"BASE ROT", "LIFT POS", "ARM EXT", "HEAD PAN", "HEAD TILT", "TRACK POS"};
    
    for(int i=0; i<6; i++) {
      float val = currentJoints[i];
      float target = targetJoints[i];
      
      fill(0, 150); noStroke();
      rect(x, y + i*40, 200, 30);
      
      // Label
      fill(255); textAlign(LEFT, TOP);
      text(names[i] + ": " + nf(val, 1, 3), x+5, y + i*40 + 5);
      
      // Bar Background
      fill(50);
      rect(x+5, y + i*40 + 20, 190, 4);
      
      // Target Marker (Red)
      float tX = map(target, -1, 1, 0, 190);
      stroke(255, 0, 0); line(x+5+tX, y + i*40 + 18, x+5+tX, y + i*40 + 26);
      
      // Current Bar (Cyan)
      float cX = map(val, -1, 1, 0, 190);
      noStroke(); fill(0, 255, 255);
      rect(x+5, y + i*40 + 20, cX, 4);
    }
  }
  
  void drawConsole(float x, float y) {
    // Only show latest log top right compact
    textAlign(RIGHT, CENTER);
    fill(100, 255, 100);
    text(logs.getLast(), width - 20, 30);
  }
  
  void drawSubtitles() {
    float boxH = 100;
    fill(0, 220);
    rect(0, height - boxH, width, boxH);
    
    // AI Text
    fill(255); textFont(fontBold); textSize(20); textAlign(CENTER, CENTER);
    text(aiMessage, width/2, height - boxH/2);
    
    // Deco lines
    stroke(0, 255, 255); strokeWeight(2);
    line(width/2 - 200, height - boxH + 10, width/2 + 200, height - boxH + 10);
  }
}

// ==========================================
// CLASS: CINEMATIC CAMERA
// ==========================================
class CinematicCam {
  float angle = 0;
  PVector camPos = new PVector(0, -300, 800);
  PVector lookAt = new PVector(0, -100, 0);
  
  void update() {
    // Drift usor
    angle += 0.002;
    camPos.x = sin(angle) * 900;
    camPos.z = cos(angle) * 900;
    camPos.y = -300 + sin(angle * 2) * 50;
    
    // Urmareste robotul pe sina
    float trackPos = map(currentJoints[5], -1, 1, -400, 400);
    lookAt.x = lerp(lookAt.x, trackPos, 0.05);
  }
  
  void apply() {
    camera(camPos.x, camPos.y, camPos.z, 
           lookAt.x, lookAt.y, lookAt.z, 
           0, 1, 0);
  }
}

// ==========================================
// OSC COMMUNICATION HANDLER
// ==========================================
void oscEvent(OscMessage msg) {
  if(msg.checkAddrPattern("/joints")) {
    for(int i=0; i<6; i++) {
      targetJoints[i] = msg.get(i).floatValue();
    }
    // Update logs rar ca sa nu spamam
    if(millis() - lastPacketTime > 2000) {
      hud.addLog("KINEMATICS UPDATED");
      lastPacketTime = millis();
    }
  }
  else if(msg.checkAddrPattern("/text")) {
    aiMessage = msg.get(0).stringValue();
    hud.addLog("AI: " + (aiMessage.length() > 20 ? aiMessage.substring(0, 20)+"..." : aiMessage));
  }
  else if(msg.checkAddrPattern("/status")) {
    aiStatus = msg.get(0).stringValue();
    hud.addLog("STATUS CHANGE: " + aiStatus);
  }
  else if(msg.checkAddrPattern("/user")) {
    // Daca vrei sa afisezi si ce zice userul pe ecran
    // Momentan e doar in log
    hud.addLog("USER INPUT RCV");
  }
}
