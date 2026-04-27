import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  static const List<String> gradosDisponibles = [
    'Técnico superior en Desarrollo de Aplicaciones Web',
    'Técnico superior en Desarrollo de Aplicaciones Multiplataforma',
    'Técnico superior en Administración de Sistemas Informáticos en Red',
    'Técnico superior en Gestión de Alojamientos Turísticos en Madrid',
    'Técnico superior en Administración y Finanzas en Madrid',
    'Técnico superior en Enseñanza y Animación Sociodeportiva',
    'Técnico superior en Acondicionamiento Físico',
    'Técnico superior en Radioterapia y Dosimetría',
    'Técnico superior en Imagen para el Diagnóstico y Medicina Nuclear',
    'Técnico superior en Educación Infantil',
    'Técnico en Sistemas Microinformáticos y Redes',
    'Técnico en Gestión Administrativa',
    'Técnico en Guía en el Medio Natural y de Tiempo Libre',
    'Técnico en Cuidados Auxiliares de Enfermería',
    'Técnico en Emergencias Sanitarias',
  ];

  String _gradoSeleccionado = gradosDisponibles.first;

  Future<void> _registrarse() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _nombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted && credential.user != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(credential.user!.uid)
            .set({
          'email': _emailController.text.trim(),
          'nombre': _nombreController.text.trim(),
          'ciclo': _gradoSeleccionado,
        });

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PantallaPrincipal(cicloAlumno: _gradoSeleccionado),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Icon(Icons.person_add, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'Crea tu cuenta',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _nombreController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person, color: Colors.white70),
                    hintText: 'Nombre completo',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email, color: Colors.white70),
                    hintText: 'Email',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                    hintText: 'Contraseña',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _gradoSeleccionado,
                  dropdownColor: const Color(0xFF1976D2),
                  decoration: InputDecoration(
                    labelText: 'Grado del que quieres ofertas',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: gradosDisponibles.map((grado) {
                    return DropdownMenuItem(
                      value: grado,
                      child: Text(grado, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _gradoSeleccionado = val);
                  },
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _registrarse,
                        child: const Text('REGISTRARSE'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
