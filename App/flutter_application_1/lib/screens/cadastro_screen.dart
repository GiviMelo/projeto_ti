import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({Key? key}) : super(key: key);

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _loading = false;

  final Color roxo = const Color(0xFF522365);
  final Color roxoEscuro = const Color(0xFF3C205A);
  final Color verdeFundo = const Color(0xFFEBFFD7);

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
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

  Future<void> _handleCadastro() async {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    final confirmarSenha = _confirmarSenhaController.text;

    if (nome.isEmpty ||
        email.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty) {
      _showAlert('Erro', 'Por favor, preencha todos os campos.');
      return;
    }

    if (senha != confirmarSenha) {
      _showAlert('Erro', 'As senhas não coincidem.');
      return;
    }

    if (senha.length < 6) {
      _showAlert('Erro', 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Cria a conta no Firebase Authentication (E-mail e Senha)
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: senha);

      // Pega o ID único gerado pelo Firebase para esse usuário
      String uid = userCredential.user!.uid;

      // 2. Grava os outros dados (Nome e Pontos zerados) no Realtime Database
      await FirebaseDatabase.instance.ref().child('usuarios').child(uid).set({
        'name': nome,
        'email': email,
        'points': 0,
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Sucesso'),
            content: const Text(
              'Conta criada com sucesso! Faça seu login para continuar.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'Falha ao cadastrar.';
      if (e.code == 'email-already-in-use') {
        mensagemErro = 'Este e-mail já está sendo usado por outra conta.';
      } else if (e.code == 'invalid-email') {
        mensagemErro = 'O formato do e-mail digitado é inválido.';
      } else if (e.code == 'weak-password') {
        mensagemErro = 'A senha escolhida é muito fraca.';
      }
      _showAlert('Erro', mensagemErro);
    } catch (e) {
      _showAlert('Erro', 'Erro de conexão com o banco de dados: $e');
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
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 20.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crie sua conta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    color: roxoEscuro,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                Text(
                  'Nome',
                  style: TextStyle(
                    color: roxoEscuro,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nomeController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                Text(
                  'Email',
                  style: TextStyle(
                    color: roxoEscuro,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
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
                const SizedBox(height: 15),

                Text(
                  'Senha',
                  style: TextStyle(
                    color: roxoEscuro,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
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
                const SizedBox(height: 15),

                Text(
                  'Confirmar Senha',
                  style: TextStyle(
                    color: roxoEscuro,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmarSenhaController,
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
                const SizedBox(height: 35),

                ElevatedButton(
                  onPressed: _loading ? null : _handleCadastro,
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
                          'CADASTRAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                TextButton(
                  // Trocado Navigator.pop por Navigator.push
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  ),
                  child: Text(
                    'Já tem uma conta? Faça Login',
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
