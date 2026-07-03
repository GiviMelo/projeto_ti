#include <SoftwareSerial.h>

// === DEFINIÇÃO DE PINOS ===
// Pinos do Shift Register usado para controlar o display de 7 segmentos
const int LatchPin = 4;
const int ClockPin = 7;
const int DataPin = 8;

// Pinos de saída para os LEDs e pinos de entrada para os botões
const int LEDS[] = {13, 12, 11, 10}; 
const int BUTTONS[] = {A1, A2, A3};

// Pinos do Buzzer e do módulo Bluetooth
const int BUZZER = 3;
const int BT_RX = 5;
const int BT_TX = 6;
SoftwareSerial BTSerial(BT_RX, BT_TX); // Instancia a serial do Bluetooth nos pinos 5 e 6

// Códigos para formar números e letras no display
const byte SEGMENT_MAP[] = {
  0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90, 
  0xC1, 0x86, 0xBF, 0xFF 
};
// Selecionar qual dos 4 dígitos do display será aceso no momento
const byte DIGIT_MAP[] = {0x08, 0x04, 0x02, 0x01};

// Possíveis estados em que o jogo pode estar
enum EstadoJogo { CONFIGURACAO, INICIANDO, CORRENDO, SUCESSO, GAME_OVER };
EstadoJogo estadoAtual = CONFIGURACAO; // O jogo sempre inicia na tela de configuração

// === VARIÁVEIS DO JOGO ===
const int SENHA_TAMANHO = 30; // Tamanho máximo da sequência que o jogador precisa acertar
int senha[SENHA_TAMANHO];     // Array que guardará a sequência gerada aleatoriamente
int progressoSenha = 0;       // Em qual etapa da sequência o jogador está

int tempoMaximoInicial = 30;  // Tempo inicial configurável da partida
float tempoRestante = 30;     // Tempo que vai decrescendo durante o jogo
float velocidadeTempo = 1.0;  // Fator que acelera o cronômetro quando o jogador erra

int sequenciaAtual = 0;       // Conta quantos acertos seguidos o jogador teve
int maiorPontuacao = 0;       // Armazena o recorde de acertos
bool resultadoEnviado = false;// Garante que a pontuação seja enviada via Bluetooth apenas uma vez

// Controle de tempo
unsigned long ultimoTempoAtualizacao = 0;
unsigned long ultimoTempoBuzzer = 0;
bool estadoBuzzerCritico = false;
unsigned long tempoInicioGo = 0;

// Armazena o último estado lido de cada botão
bool ultimoEstadoBotao[3] = {HIGH, HIGH, HIGH};

void setup() {
  // Configura os pinos como saída
  pinMode(LatchPin, OUTPUT);
  pinMode(ClockPin, OUTPUT);
  pinMode(DataPin, OUTPUT);

  // Configura os LEDs como saída e garante que iniciem apagados
  for (int i = 0; i < 4; i++) {
    pinMode(LEDS[i], OUTPUT);
    digitalWrite(LEDS[i], HIGH); 
  }

  // Configura os botões como entrada
  for (int i = 0; i < 3; i++) {
    pinMode(BUTTONS[i], INPUT_PULLUP);
  }

  // Configura o buzzer
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, HIGH); // HIGH geralmente desliga buzzers com lógica invertida

  // Inicia a comunicação serial para debug no computador e a comunicação Bluetooth
  Serial.begin(9600); 
  BTSerial.begin(9600); 

  // Gera uma senha aleatória
  randomSeed(analogRead(A5));
  gerarSenha();
}

void loop() {
  atualizarDisplay(); // Mantém o display de 7 segmentos aceso
  processarEstado();  // Roda a lógica do jogo dependendo do estado atual
}

void processarEstado() {
  unsigned long tempoAtual = millis(); // Captura o tempo atual do sistema

  switch (estadoAtual) {
    case CONFIGURACAO:
      // Botão 0: Aumenta o tempo inicial da partida (máximo 90s)
      if (checarBotaoPressionado(0)) {
        tempoMaximoInicial += 5;
        if (tempoMaximoInicial > 90) tempoMaximoInicial = 90;
        tocarBipeConfig();
      }

      // Botão 1: Diminui o tempo inicial da partida (mínimo 10s)
      if (checarBotaoPressionado(1)) {
        tempoMaximoInicial -= 5;
        if (tempoMaximoInicial < 10) tempoMaximoInicial = 10;
        tocarBipeConfig();
      }

      // Reseta as variáveis para o início de uma nova partida
      tempoRestante = tempoMaximoInicial;
      velocidadeTempo = 1.0;
      progressoSenha = 0;
      sequenciaAtual = 0; 
      resultadoEnviado = false;
      atualizarLedsBinario(0); // Apaga os LEDs de progresso

      // Botão 2: Confirma a configuração e muda para o estado de início
      if (checarBotaoPressionado(2)) {
        tempoInicioGo = tempoAtual;
        estadoAtual = INICIANDO;
      }
      break;

    case INICIANDO:
      // Aguarda 1 segundo antes de mudar o estado para CORRENDO
      if (tempoAtual - tempoInicioGo >= 1000) {
        ultimoTempoAtualizacao = tempoAtual;
        estadoAtual = CORRENDO;
      }
      break;

    case CORRENDO:
      // Diminui 1 segundo do tempo restante baseado na 'velocidadeTempo'
      if (tempoAtual - ultimoTempoAtualizacao >= (1000 / velocidadeTempo)) {
        ultimoTempoAtualizacao = tempoAtual;
        tempoRestante--;

        // Se o tempo zerar, Game Over
        if (tempoRestante <= 0) {
          tempoRestante = 0;
          estadoAtual = GAME_OVER;
          digitalWrite(BUZZER, LOW); // Liga o buzzer permanentemente ou emite som de falha
        }
      }

      // Alarme crítico: Quando resta apenas 10% do tempo, o buzzer apita periodicamente
      if (estadoAtual == CORRENDO && tempoRestante <= (tempoMaximoInicial * 0.10) && tempoRestante > 0) {
        if (tempoAtual - ultimoTempoBuzzer >= 1000) {
          ultimoTempoBuzzer = tempoAtual;
          digitalWrite(BUZZER, LOW); // Liga o apito
          estadoBuzzerCritico = true;
        }
        if (estadoBuzzerCritico && (tempoAtual - ultimoTempoBuzzer >= 100)) {
          digitalWrite(BUZZER, HIGH); // Desliga o apito 
          estadoBuzzerCritico = false;
        }
      }

      // Verifica se o jogador pressionou algum dos 3 botões da senha
      for (int i = 0; i < 3; i++) {
        if (checarBotaoPressionado(i)) {
          // Os números gerados vão de 1 a 3, mas o índice do botão é 0 a 2. Subtrai-se 1 para comparar.
          int botaoEsperado = senha[progressoSenha] - 1;

          if (i == botaoEsperado) {
            // ACERTOU
            progressoSenha++;
            sequenciaAtual++; 

            // Atualiza o recorde máximo de pontuação em tempo real
            if (sequenciaAtual > maiorPontuacao) {
              maiorPontuacao = sequenciaAtual;
            }

            atualizarLedsBinario(progressoSenha); // Atualiza os LEDs para mostrar o progresso

            // Se completou a senha toda, ganha o jogo
            if (progressoSenha >= SENHA_TAMANHO) {
              estadoAtual = SUCESSO;
              tocarBipesSucesso();
            }
          } else {
            // ERROU
            progressoSenha = 0; // Zera o progresso da senha
            sequenciaAtual = 0; // Zera a sequência de acertos atual
            atualizarLedsBinario(0); // Apaga os LEDs de progresso
            velocidadeTempo += 0.05; // O cronômetro passa a correr mais rápido
            tocarBipeErro();
          }
        }
      }
      break;

    case SUCESSO:
    case GAME_OVER:
      // Ambos os casos de fim de jogo chamam a função para enviar a pontuação via Bluetooth
      enviarMaiorPontuacao(); 
      break;
  }
}


// Preenche o array 'senha' com números aleatórios entre 1 e 3
void gerarSenha() {
  for (int i = 0; i < SENHA_TAMANHO; i++) {
    senha[i] = random(1, 4);
  }
}

// Verifica se o botão foi pressionado
bool checarBotaoPressionado(int indiceBotao) {
  bool estadoLeitura = digitalRead(BUTTONS[indiceBotao]);
  bool pressionado = false;

  // Se o sinal foi para LOW (apertou) e antes estava HIGH (solto)
  if (estadoLeitura == LOW && ultimoEstadoBotao[indiceBotao] == HIGH) {
    delay(5); // Pequena pausa para ignorar ruídos físicos do contato do botão
    if (digitalRead(BUTTONS[indiceBotao]) == LOW) {
      pressionado = true;
    }
  }
  ultimoEstadoBotao[indiceBotao] = estadoLeitura; // Salva o estado atual para a próxima leitura
  return pressionado;
}

// Exibe o progresso do jogador em formato binário utilizando os 4 LEDs
void atualizarLedsBinario(int valor) {
  // Se o bit for 1, o pino vai para LOW (liga o LED), se 0, vai para HIGH (desliga)
  digitalWrite(LEDS[0], (valor & 0x01) ? LOW : HIGH);
  digitalWrite(LEDS[1], (valor & 0x02) ? LOW : HIGH);
  digitalWrite(LEDS[2], (valor & 0x04) ? LOW : HIGH);
  digitalWrite(LEDS[3], (valor & 0x08) ? LOW : HIGH);
}

// Emite um bipe rápido para indicar mudança na configuração
void tocarBipeConfig() {
  digitalWrite(BUZZER, LOW);
  delay(30);
  digitalWrite(BUZZER, HIGH);
}

// Emite um bipe longo indicando que o jogador errou o botão
void tocarBipeErro() {
  digitalWrite(BUZZER, LOW);
  delay(150);
  digitalWrite(BUZZER, HIGH);
}

// Toca uma sequência de 3 bipes para celebrar a vitória
void tocarBipesSucesso() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER, LOW);
    delay(150);
    digitalWrite(BUZZER, HIGH);
    delay(100);
  }
}

// Envia a pontuação máxima alcançada para o celular ou PC via Bluetooth
void enviarMaiorPontuacao() {
  if (resultadoEnviado) return; // Se já enviou, sai da função

  String mensagem = "MAIOR_PONTUACAO:" + String(maiorPontuacao);

  BTSerial.println(mensagem); // Envia pelo módulo Bluetooth
  Serial.println(mensagem);   // Envia pela porta USB do Arduino (Debug)

  resultadoEnviado = true; // Marca que o envio foi concluído
}

// Função para enviar dados e controlar o display
void enviarDisplay(byte digito, byte caractere) {
  digitalWrite(LatchPin, LOW); // Avisa o CI que vai começar a enviar dados
  shiftOut(DataPin, ClockPin, MSBFIRST, caractere); // Envia o caractere
  shiftOut(DataPin, ClockPin, MSBFIRST, digito);    // Envia o dígito
  digitalWrite(LatchPin, HIGH); // Avisa o CI que terminou e pode exibir a informação
}

// Atualiza rapidamente cada dígito do display de 7 segmentos
void atualizarDisplay() {
  static byte digitoAtual = 0; // Mantém a memória do último dígito exibido a cada ciclo do loop()

  switch (estadoAtual) {
    case CONFIGURACAO:
    case CORRENDO:
      {
        int tempoDisp = (int)tempoRestante;
        int dezenas = (tempoDisp % 100) / 10;
        int unidades = tempoDisp % 10;

        // Exibe o tempo apenas nos dois primeiros dígitos. O restante fica apagado
        if (digitoAtual == 0) enviarDisplay(DIGIT_MAP[0], SEGMENT_MAP[unidades]);
        if (digitoAtual == 1) enviarDisplay(DIGIT_MAP[1], SEGMENT_MAP[dezenas]);
        if (digitoAtual == 2) enviarDisplay(DIGIT_MAP[2], SEGMENT_MAP[13]);
        if (digitoAtual == 3) enviarDisplay(DIGIT_MAP[3], SEGMENT_MAP[13]);
      }
      break;

    case INICIANDO:
      // Exibe "GO  " na tela
      if (digitoAtual == 0) enviarDisplay(DIGIT_MAP[0], SEGMENT_MAP[11]); // 'O'
      if (digitoAtual == 1) enviarDisplay(DIGIT_MAP[1], SEGMENT_MAP[10]); // 'G'
      if (digitoAtual == 2) enviarDisplay(DIGIT_MAP[2], SEGMENT_MAP[13]);
      if (digitoAtual == 3) enviarDisplay(DIGIT_MAP[3], SEGMENT_MAP[13]);
      break;

    case SUCESSO:
      // Exibe "FFO "
      if (digitoAtual == 0) enviarDisplay(DIGIT_MAP[0], 0x8E); // 'F'
      if (digitoAtual == 1) enviarDisplay(DIGIT_MAP[1], 0x8E); // 'F'
      if (digitoAtual == 2) enviarDisplay(DIGIT_MAP[2], SEGMENT_MAP[11]); // 'O'
      if (digitoAtual == 3) enviarDisplay(DIGIT_MAP[3], SEGMENT_MAP[13]);
      break;

    case GAME_OVER:
      // Exibe "0000" para indicar fim de jogo de forma visual
      if (digitoAtual == 0) enviarDisplay(DIGIT_MAP[0], SEGMENT_MAP[0]);
      if (digitoAtual == 1) enviarDisplay(DIGIT_MAP[1], SEGMENT_MAP[0]);
      if (digitoAtual == 2) enviarDisplay(DIGIT_MAP[2], SEGMENT_MAP[0]);
      if (digitoAtual == 3) enviarDisplay(DIGIT_MAP[3], SEGMENT_MAP[0]);
      break;
  }

  // Passa para o próximo dígito no ciclo seguinte (0 -> 1 -> 2 -> 3 -> 0...)
  digitoAtual = (digitoAtual + 1) % 4;
}
