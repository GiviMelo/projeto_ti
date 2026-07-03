#include <SoftwareSerial.h>

const int LatchPin = 4;
const int ClockPin = 7;
const int DataPin = 8;

const int LEDS[] = {13, 12, 11, 10}; 
const int BUTTONS[] = {A1, A2, A3};

const int BUZZER = 3;
const int BT_RX = 5;
const int BT_TX = 6;
SoftwareSerial BTSerial(BT_RX, BT_TX);

const byte SEGMENT_MAP[] = {
  0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90, 
  0xC1, 0x86, 0xBF, 0xFF 
};
const byte DIGIT_MAP[] = {0x08, 0x04, 0x02, 0x01};

enum EstadoJogo { CONFIGURACAO, INICIANDO, CORRENDO, SUCESSO, GAME_OVER };
EstadoJogo estadoAtual = CONFIGURACAO;

const int SENHA_TAMANHO = 30; 
int senha[SENHA_TAMANHO];
int progressoSenha = 0;

int tempoMaximoInicial = 30; 
float tempoRestante = 30;
float velocidadeTempo = 1.0;

// MODIFICADO: Alterado de acertosTotais para sequenciaAtual
int sequenciaAtual = 0; 
int maiorPontuacao = 0; 
bool resultadoEnviado = false; 

unsigned long ultimoTempoAtualizacao = 0;
unsigned long ultimoTempoBuzzer = 0;
bool estadoBuzzerCritico = false;
unsigned long tempoInicioGo = 0;

bool ultimoEstadoBotao[3] = {HIGH, HIGH, HIGH};

void setup() {
  pinMode(LatchPin, OUTPUT);
  pinMode(ClockPin, OUTPUT);
  pinMode(DataPin, OUTPUT);

  for (int i = 0; i < 4; i++) {
    pinMode(LEDS[i], OUTPUT);
    digitalWrite(LEDS[i], HIGH); 
  }

  for (int i = 0; i < 3; i++) {
    pinMode(BUTTONS[i], INPUT_PULLUP);
  }

  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, HIGH); 

  Serial.begin(9600); 
  BTSerial.begin(9600); 

  randomSeed(analogRead(A5));
  gerarSenha();
}

void loop() {
  atualizarDisplay();
  processarEstado();
}

void processarEstado() {
  unsigned long tempoAtual = millis();

  switch (estadoAtual) {
    case CONFIGURACAO:
      if (checarBotaoPressionado(0)) {
        tempoMaximoInicial += 5;
        if (tempoMaximoInicial > 90) tempoMaximoInicial = 90;
        tocarBipeConfig();
      }

      if (checarBotaoPressionado(1)) {
        tempoMaximoInicial -= 5;
        if (tempoMaximoInicial < 10) tempoMaximoInicial = 10;
        tocarBipeConfig();
      }

      tempoRestante = tempoMaximoInicial;
      velocidadeTempo = 1.0;
      progressoSenha = 0;
      sequenciaAtual = 0; // MODIFICADO
      resultadoEnviado = false;
      atualizarLedsBinario(0);

      if (checarBotaoPressionado(2)) {
        tempoInicioGo = tempoAtual;
        estadoAtual = INICIANDO;
      }
      break;

    case INICIANDO:
      if (tempoAtual - tempoInicioGo >= 1000) {
        ultimoTempoAtualizacao = tempoAtual;
        estadoAtual = CORRENDO;
      }
      break;

    case CORRENDO:
      if (tempoAtual - ultimoTempoAtualizacao >= (1000 / velocidadeTempo)) {
        ultimoTempoAtualizacao = tempoAtual;
        tempoRestante--;

        if (tempoRestante <= 0) {
          tempoRestante = 0;
          estadoAtual = GAME_OVER;
          digitalWrite(BUZZER, LOW);
        }
      }

      if (estadoAtual == CORRENDO && tempoRestante <= (tempoMaximoInicial * 0.10) && tempoRestante > 0) {
        if (tempoAtual - ultimoTempoBuzzer >= 1000) {
          ultimoTempoBuzzer = tempoAtual;
          digitalWrite(BUZZER, LOW);
          estadoBuzzerCritico = true;
        }
        if (estadoBuzzerCritico && (tempoAtual - ultimoTempoBuzzer >= 100)) {
          digitalWrite(BUZZER, HIGH);
          estadoBuzzerCritico = false;
        }
      }

      for (int i = 0; i < 3; i++) {
        if (checarBotaoPressionado(i)) {
          int botaoEsperado = senha[progressoSenha] - 1;

          if (i == botaoEsperado) {
            progressoSenha++;
            sequenciaAtual++; // MODIFICADO: Aumenta a sequência atual

            // MODIFICADO: Atualiza a maior sequência alcançada em tempo real
            if (sequenciaAtual > maiorPontuacao) {
              maiorPontuacao = sequenciaAtual;
            }

            atualizarLedsBinario(progressoSenha);

            if (progressoSenha >= SENHA_TAMANHO) {
              estadoAtual = SUCESSO;
              tocarBipesSucesso();
            }
          } else {
            progressoSenha = 0;
            sequenciaAtual = 0; // MODIFICADO: Errou, a sequência atual zera
            atualizarLedsBinario(0);
            velocidadeTempo += 0.05;
            tocarBipeErro();
          }
        }
      }
      break;

    case SUCESSO:
    case GAME_OVER:
      enviarMaiorPontuacao(); 
      break;
  }
}

void gerarSenha() {
  for (int i = 0; i < SENHA_TAMANHO; i++) {
    senha[i] = random(1, 4); 
  }
}

bool checarBotaoPressionado(int indiceBotao) {
  bool estadoLeitura = digitalRead(BUTTONS[indiceBotao]);
  bool pressionado = false;

  if (estadoLeitura == LOW && ultimoEstadoBotao[indiceBotao] == HIGH) {
    delay(5); 
    if (digitalRead(BUTTONS[indiceBotao]) == LOW) {
      pressionado = true;
    }
  }
  ultimoEstadoBotao[indiceBotao] = estadoLeitura;
  return pressionado;
}

void atualizarLedsBinario(int valor) {
  digitalWrite(LEDS[0], (valor & 0x01) ? LOW : HIGH);
  digitalWrite(LEDS[1], (valor & 0x02) ? LOW : HIGH);
  digitalWrite(LEDS[2], (valor & 0x04) ? LOW : HIGH);
  digitalWrite(LEDS[3], (valor & 0x08) ? LOW : HIGH);
}

void tocarBipeConfig() {
  digitalWrite(BUZZER, LOW);
  delay(30);
  digitalWrite(BUZZER, HIGH);
}

void tocarBipeErro() {
  digitalWrite(BUZZER, LOW);
  delay(150);
  digitalWrite(BUZZER, HIGH);
}

void tocarBipesSucesso() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER, LOW);
    delay(150);
    digitalWrite(BUZZER, HIGH);
    delay(100);
  }
}

void enviarMaiorPontuacao() {
  if (resultadoEnviado) return;

  String mensagem = "MAIOR_PONTUACAO:" + String(maiorPontuacao);

  BTSerial.println(mensagem);
  Serial.println(mensagem);

  resultadoEnviado = true;
}

void enviarDisplay(byte digito, byte caractere) {
  digitalWrite(LatchPin, LOW);
  shiftOut(DataPin, ClockPin, MSBFIRST, caractere);
  shiftOut(DataPin, ClockPin, MSBFIRST, digito);
  digitalWrite(LatchPin, HIGH);
}

void atualizarDisplay() {
  static byte digitoAtual = 0;

  switch (estadoAtual) {
    case CONFIGURACAO:
    case CORRENDO:
      {
        int tempoDisp = (int)tempoRestante;
        int dezenas = (tempoDisp % 100) / 10;
        int unidades = tempoDisp % 10;

        if (digitoAtual == 0) enviarDisplay(DIGIT_MAP[0], SEGMENT_MAP[unidades]);
        if (digitoAtual == 1) enviarDisplay(DIGIT_MAP[1], SEGMENT_MAP[dezenas]);
        if (digitoAtual == 2) enviarDisplay(DIGIT_MAP[2], SEGMENT_MAP[13]);
        if (digitoAtual == 3) enviarDisplay(DIGIT_MAP[3], SEGMENT_MAP[13]);
      }
      break;

    case INICIANDO:
      if (digitoAtual == 0) enviarDisplay(DIGIT_MAP[0], SEGMENT_MAP[11]); // 'O'
      if (digitoAtual == 1) enviarDisplay(DIGIT_MAP[1], SEGMENT_MAP[10]); // 'G'
      if (digitoAtual == 2) enviarDisplay(DIGIT_MAP[2], SEGMENT_MAP[13]);
      if (digitoAtual == 3) enviarDisplay(DIGIT_MAP[3], SEGMENT_MAP[13]);
      break;

    case SUCESSO:
      if (digitoAtual == 0) enviarDisplay(DIGIT_MAP[0], 0x8E); // 'F'
      if (digitoAtual == 1) enviarDisplay(DIGIT_MAP[1], 0x8E); // 'F'
      if (digitoAtual == 2) enviarDisplay(DIGIT_MAP[2], SEGMENT_MAP[11]); // 'O'
      if (digitoAtual == 3) enviarDisplay(DIGIT_MAP[3], SEGMENT_MAP[13]);
      break;

    case GAME_OVER:
      if (digitoAtual == 0) enviarDisplay(DIGIT_MAP[0], SEGMENT_MAP[0]);
      if (digitoAtual == 1) enviarDisplay(DIGIT_MAP[1], SEGMENT_MAP[0]);
      if (digitoAtual == 2) enviarDisplay(DIGIT_MAP[2], SEGMENT_MAP[0]);
      if (digitoAtual == 3) enviarDisplay(DIGIT_MAP[3], SEGMENT_MAP[0]);
      break;
  }

  digitoAtual = (digitoAtual + 1) % 4;
}