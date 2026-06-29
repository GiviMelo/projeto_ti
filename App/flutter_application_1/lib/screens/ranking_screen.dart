import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';
import 'bluetooth_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({Key? key}) : super(key: key);

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  String? currentUserId;

  final Color roxoRecicom = const Color(0xFF522365);
  final Color roxoEscuro = const Color(0xFF3C205A);
  final Color roxoTexto = const Color(0xFF483360);
  final Color verdeFundo = const Color(0xFFEBFFD7);

  @override
  void initState() {
    super.initState();
    // Pega o ID do usuário que está logado no momento para destacá-lo no ranking
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: roxoRecicom,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.logout, size: 28, color: Colors.white),
                tooltip: 'Sair e voltar para o login',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  }
                },
              ),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: verdeFundo,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                padding: const EdgeInsets.only(
                  left: 30,
                  right: 30,
                  top: 40,
                  bottom: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ranking',
                      style: TextStyle(
                        fontSize: 40,
                        color: roxoEscuro,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Icon(Icons.emoji_events, size: 45, color: roxoEscuro),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comunidade',
                              style: TextStyle(fontSize: 25, color: roxoTexto),
                            ),
                            Text(
                              'Junte-se a nós!',
                              style: TextStyle(fontSize: 15, color: roxoTexto),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    Expanded(
                      child: StreamBuilder(
                        stream: FirebaseDatabase.instance
                            .ref()
                            .child('usuarios')
                            .orderByChild('points')
                            .onValue,
                        builder:
                            (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Erro ao carregar ranking: ${snapshot.error}',
                                  ),
                                );
                              }

                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: roxoEscuro,
                                  ),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data?.snapshot.value == null) {
                                return Center(
                                  child: Text(
                                    'Nenhum usuário pontuou ainda.',
                                    style: TextStyle(
                                      color: roxoEscuro,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              }

                              final Map<dynamic, dynamic> usuariosMap =
                                  snapshot.data!.snapshot.value
                                      as Map<dynamic, dynamic>;

                              List<Map<String, dynamic>> listaUsuarios = [];
                              usuariosMap.forEach((key, value) {
                                listaUsuarios.add({
                                  'uid': key,
                                  'name': value['name'] ?? 'Sem nome',
                                  'points': value['points'] ?? 0,
                                });
                              });

                              listaUsuarios.sort(
                                (a, b) => b['points'].compareTo(a['points']),
                              );

                              return ListView.builder(
                                itemCount: listaUsuarios.length,
                                itemBuilder: (context, index) {
                                  final user = listaUsuarios[index];
                                  final rank = index + 1;
                                  final bool isCurrentUser =
                                      user['uid'] == currentUserId;

                                  return _buildRankingRow(
                                    rank: rank,
                                    name: isCurrentUser
                                        ? "${user['name']} (Você)"
                                        : user['name'],
                                    points: user['points'],
                                    isCurrentUser: isCurrentUser,
                                  );
                                },
                              );
                            },
                      ),
                    ),

                    const SizedBox(height: 15),

                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BluetoothScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bluetooth, color: Colors.white),
                      label: const Text(
                        'CONECTAR ARDUINO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: roxoRecicom,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingRow({
    required int rank,
    required String name,
    required int points,
    required bool isCurrentUser,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              "$rank-",
              style: TextStyle(
                fontSize: isCurrentUser ? 24 : 20,
                color: roxoEscuro,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.person,
              size: isCurrentUser ? 44 : 31,
              color: roxoEscuro,
            ),
          ),

          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: isCurrentUser ? 22 : 20,
                color: roxoEscuro,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),

          Text(
            "$points pnts",
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isCurrentUser ? 18 : 15,
              color: roxoEscuro,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
