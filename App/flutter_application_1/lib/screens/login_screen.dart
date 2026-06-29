import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cadastro_screen.dart';
import 'ranking_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _loading = false;

  final Color roxo = const Color(0xFF522365);
  final Color roxoEscuro = const Color(0xFF3C205A);
  final Color verdeFundo = const Color(0xFFEBFFD7);

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      _showAlert('Erro', 'Por favor, preencha todos os campos.');
      return;
    }

    setState(() => _loading = true);

    try {
      // Faz o login na nuvem do Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      if (mounted) {
        // Se der certo, vai direto para a tela do Ranking
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RankingScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'E-mail ou senha incorretos.';
      if (e.code == 'invalid-email') {
        mensagemErro = 'O formato do e-mail é inválido.';
      } else if (e.code == 'user-disabled') {
        mensagemErro = 'Este usuário foi desativado.';
      }
      _showAlert('Falha no Login', mensagemErro);
    } catch (e) {
      _showAlert('Erro', 'Ocorreu um erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: verdeFundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Entrar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 40,
                    color: roxoEscuro,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                Text(
                  'Email',
                  style: TextStyle(
                    color: roxoEscuro,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Senha',
                  style: TextStyle(
                    color: roxoEscuro,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _loading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: roxo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ENTRAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 30),

                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CadastroScreen(),
                    ),
                  ),
                  child: Text(
                    'Não tem uma conta? Cadastre-se',
                    style: TextStyle(color: roxo, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
