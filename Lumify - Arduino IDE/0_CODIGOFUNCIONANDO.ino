#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <WiFiManager.h>
#include <fauxmoESP.h>

#define LED_PIN D1
#define PIR_PIN D2
#define SOUND_SENSOR_PIN D5
#define DEBOUNCE_TIME 200
#define RESET_TIME 500
#define LED_OFF_DELAY 10000

fauxmoESP fauxmo;
ESP8266WebServer server(8080);

bool ledState = false;
bool pirEnabled = true;
unsigned long ledOnTime = 0;
unsigned long lastClapTime = 0;
int clapCount = 0;

void handleRoot() {
  static const char html[] PROGMEM = "<html><body>"
                                     "<h1>Controle de LED e PIR</h1>"
                                     "<button onclick=\"location.href='/led/on'\">Ligar LED</button>"
                                     "<button onclick=\"location.href='/led/off'\">Desligar LED</button>"
                                     "<br><br>"
                                     "<button onclick=\"location.href='/pir/on'\">PIR ON</button>"
                                     "<button onclick=\"location.href='/pir/off'\">PIR OFF</button>"
                                     "</body></html>";
  server.send_P(200, "text/html", html);
}

void handleLEDOn() {
  ledState = true;
  pirEnabled = false;
  digitalWrite(LED_PIN, LOW); // Atualizado para LED_PIN
  server.send(200, "text/plain", PSTR("LED ligado"));
}

void handleLEDOff() {
  ledState = false;
  digitalWrite(LED_PIN, HIGH); // Atualizado para LED_PIN
  server.send(200, "text/plain", PSTR("LED desligado"));
}

void handlePIROn() {
  pirEnabled = true;
  server.send(200, "text/plain", PSTR("PIR ativado"));
}

void handlePIROff() {
  pirEnabled = false;
  server.send(200, "text/plain", PSTR("PIR desativado"));
}

void handleLEDStatus() {
  server.send(200, "text/plain", ledState ? PSTR("Ligado") : PSTR("Desligado"));
}

void handlePIRStatus() {
  server.send(200, "text/plain", pirEnabled ? PSTR("Ativado") : PSTR("Desativado"));
}

void setup() {
  Serial.begin(115200);

  pinMode(LED_PIN, OUTPUT);
  pinMode(PIR_PIN, INPUT);
  pinMode(SOUND_SENSOR_PIN, INPUT);

  WiFiManager wifiManager;
  wifiManager.autoConnect("NodeMCU_LED_AP");

  Serial.println("Conectado ao Wi-Fi!");
  Serial.print("Endereço IP: ");
  Serial.println(WiFi.localIP());

  fauxmo.setPort(80);
  fauxmo.enable(true);

  server.on("/", handleRoot);
  server.on("/led/on", handleLEDOn);
  server.on("/led/off", handleLEDOff);
  server.on("/pir/on", handlePIROn);
  server.on("/pir/off", handlePIROff);
  server.on("/led/status", handleLEDStatus);
  server.on("/pir/status", handlePIRStatus);

  server.begin();
  Serial.println("Servidor web iniciado na porta 8080!");

  fauxmo.addDevice("LED");
  fauxmo.addDevice("PIR");
    fauxmo.onSetState([](unsigned char device_id, const char *device_name, bool state, unsigned char value) {
      if (strcmp(device_name, "LED") == 0) {
        ledState = state;
        digitalWrite(LED_PIN, ledState ? LOW : HIGH);
        if (state) {
          pirEnabled = false;
        }
      } else if (strcmp(device_name, "PIR") == 0) {
        pirEnabled = state;
      }
    });
}

void loop() {
  server.handleClient();
  fauxmo.handle();

  int soundState = digitalRead(SOUND_SENSOR_PIN);
  unsigned long currentTime = millis();

  if (soundState == HIGH && currentTime - lastClapTime > DEBOUNCE_TIME) {
    lastClapTime = currentTime;
    clapCount++;

    if (clapCount == 2) {
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState ? LOW : HIGH);
      pirEnabled = false;
      clapCount = 0;
    }
  } else if (currentTime - lastClapTime > RESET_TIME) {
    clapCount = 0;
  }

  if (pirEnabled) {
    int pirState = digitalRead(PIR_PIN);
    if (pirState == HIGH) {
      ledState = true;
      digitalWrite(LED_PIN, LOW);
      ledOnTime = millis();
    } else {
      if (millis() - ledOnTime >= LED_OFF_DELAY) {
        ledState = false;
        digitalWrite(LED_PIN, HIGH);
      }
    }
  } else {
    digitalWrite(LED_PIN, ledState ? LOW : HIGH);
  }
}

