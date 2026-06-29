import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  List<BluetoothDevice> _dispositivosPareados = [];
  bool _carregando = true;
  BluetoothConnection? _conexao;

  // Paleta de cores
  final Color roxoRecicom = const Color(0xFF522365);
  final Color roxoEscuro = const Color(0xFF3C205A);
  final Color verdeFundo = const Color(0xFFEBFFD7);

  @override
  void initState() {
    super.initState();
    _buscarDispositivos();
  }

  @override
  void dispose() {
    _conexao?.dispose();
    super.dispose();
  }

  Future<void> _buscarDispositivos() async {
    try {
      List<BluetoothDevice> dispositivos = await FlutterBluetoothSerial.instance
          .getBondedDevices();
      setState(() {
        _dispositivosPareados = dispositivos;
        _carregando = false;
      });
    } catch (erro) {
      setState(() => _carregando = false);
      _showAlert('Erro', 'Não foi possível acessar o Bluetooth.');
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: roxoEscuro)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: roxoRecicom)),
          ),
        ],
      ),
    );
  }

  void _conectarDispositivo(BluetoothDevice dispositivo) async {
    setState(() => _carregando = true);

    try {
      _conexao = await BluetoothConnection.toAddress(dispositivo.address);
      setState(() => _carregando = false);

      _showAlert(
        'Conectado!',
        'Você conectou ao ${dispositivo.name}. Jogue no Arduino, os pontos virão para cá automaticamente!',
      );

      _conexao!.input!
          .listen((data) {
            String mensagemRecebida = ascii.decode(data);

            _processarDadosDoArduino(mensagemRecebida);
          })
          .onDone(() {
            if (mounted) {
              _showAlert('Aviso', 'O dispositivo foi desconectado.');
            }
          });
    } catch (erro) {
      setState(() => _carregando = false);
      _showAlert(
        'Erro de Conexão',
        'Não foi possível conectar ao ${dispositivo.name}. Veja se ele está ligado.',
      );
    }
  }

  void _processarDadosDoArduino(String mensagemRecebida) {
    // Exemplo esperado: "ACERTOS:5;TEMPO:20;STATUS:BOOM"
    try {
      // Verifica se a mensagem contém os dados certos para não bugar com ruídos
      if (mensagemRecebida.contains("ACERTOS") &&
          mensagemRecebida.contains("TEMPO")) {
        List<String> partes = mensagemRecebida.split(';');

        int acertos = int.parse(partes[0].split(':')[1]);
        String status = partes[2].split(':')[1].trim();

        // Calcula os pontos (Ex: 10 pontos por acerto + 50 de bônus se não explodiu)
        int pontosGanhos = acertos * 10;
        if (status == "OK") {
          pontosGanhos += 50;
        }

        // Envia pro banco de dados
        _atualizarPontosNoFirebase(pontosGanhos);

        // Mostra um aviso rápido na tela de que recebeu os pontos!
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Recebido do Arduino! +$pontosGanhos pontos ganhos!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (erro) {
      print("Texto inválido recebido: $mensagemRecebida");
    }
  }

  Future<void> _atualizarPontosNoFirebase(int pontosGanhos) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      DatabaseReference refUsuario = FirebaseDatabase.instance
          .ref()
          .child('usuarios')
          .child(uid);

      DataSnapshot snapshot = await refUsuario.child('points').get();

      if (snapshot.exists) {
        int pontosAtuais = int.parse(snapshot.value.toString());
        int novaPontuacaoTotal = pontosAtuais + pontosGanhos;

        await refUsuario.update({'points': novaPontuacaoTotal});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: verdeFundo,
      appBar: AppBar(
        backgroundColor: roxoRecicom,
        title: const Text(
          'Conectar ao Jogo',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _carregando = true);
              _buscarDispositivos();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dispositivos Pareados',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  color: roxoEscuro,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pareie o Arduino (HC-05) nas configurações do seu celular antes de conectar aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: roxoEscuro.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 30),

              Expanded(
                child: _carregando
                    ? Center(
                        child: CircularProgressIndicator(color: roxoRecicom),
                      )
                    : _dispositivosPareados.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum dispositivo encontrado.',
                          style: TextStyle(color: roxoEscuro, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _dispositivosPareados.length,
                        itemBuilder: (context, index) {
                          final dispositivo = _dispositivosPareados[index];
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(
                                Icons.bluetooth,
                                color: roxoRecicom,
                                size: 30,
                              ),
                              title: Text(
                                dispositivo.name ?? "Dispositivo Desconhecido",
                                style: TextStyle(
                                  color: roxoEscuro,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(dispositivo.address),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: roxoRecicom,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () =>
                                    _conectarDispositivo(dispositivo),
                                child: const Text(
                                  'Conectar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
