import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'screens/chat_page.dart';
import 'screens/registro_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolsa Empleo SGema',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0D47A1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// 1. LOGIN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _iniciarSesion() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final doc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .get();
          final ciclo = doc.data()?['ciclo'] ?? 'Desconocido';
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PantallaPrincipal(cicloAlumno: ciclo),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle, size: 100, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'Bolsa Empleo SGema',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email, color: Colors.white70),
                    hintText: 'Email',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                    hintText: 'Contraseña',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Column(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _iniciarSesion,
                            child: const Text('ENTRAR'),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegistroScreen()),
                              );
                            },
                            child: const Text(
                              '¿No tienes cuenta? REGÍSTRATE AQUÍ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. PANTALLA PRINCIPAL (Con pestañas)
// ==========================================
class PantallaPrincipal extends StatefulWidget {
  final String cicloAlumno;
  const PantallaPrincipal({super.key, required this.cicloAlumno});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0; // 0 = Ofertas, 1 = Agenda, 2 = Perfil
  String _cicloActual = '';

  late StreamSubscription<QuerySnapshot> _eventosSub;
  late StreamSubscription<QuerySnapshot> _ofertasSub;
  late StreamSubscription<DocumentSnapshot> _usuarioSub;
  bool _primerEvento = true;
  bool _primerOferta = true;

  @override
  void initState() {
    super.initState();
    _cicloActual = widget.cicloAlumno;
    _suscribirNotificaciones();
    _suscribirCambioGrado();
  }

  void _suscribirCambioGrado() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _usuarioSub = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final nuevoCiclo = snapshot.data()!['ciclo'] as String?;
              if (nuevoCiclo != null && nuevoCiclo != _cicloActual) {
                setState(() {
                  _cicloActual = nuevoCiclo;
                });
              }
            }
          });
    }
  }

  void _suscribirNotificaciones() {
    _eventosSub = FirebaseFirestore.instance
        .collection('eventos')
        .snapshots()
        .listen((snapshot) {
          if (_primerEvento) {
            _primerEvento = false;
            return;
          }
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              _mostrarNotificacion('Se ha publicado un evento.');
            }
          }
        }, onError: (_) {});

    _ofertasSub = FirebaseFirestore.instance
        .collection('ofertas')
        .where('activa', isEqualTo: true)
        .where('target_ciclos', arrayContains: widget.cicloAlumno)
        .snapshots()
        .listen((snapshot) {
          if (_primerOferta) {
            _primerOferta = false;
            return;
          }
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              _mostrarNotificacion('Se ha publicado una oferta para tu ciclo.');
            }
          }
        }, onError: (_) {});
  }

  void _mostrarNotificacion(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), duration: const Duration(seconds: 3)),
    );
  }

  @override
  void dispose() {
    _eventosSub.cancel();
    _ofertasSub.cancel();
    _usuarioSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pantallas = [
      ListaOfertasTab(cicloAlumno: _cicloActual),
      const ListaEventosTab(),
      PerfilTab(cicloAlumno: _cicloActual),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _indiceActual == 0
              ? 'Ofertas $_cicloActual 💼'
              : _indiceActual == 1
              ? 'Agenda Eventos 📅'
              : 'Mi perfil',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: pantallas[_indiceActual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) => setState(() => _indiceActual = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work), label: "Empleo"),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: "Agenda"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Mi perfil"),
        ],
      ),
    );
  }
}

class PerfilTab extends StatefulWidget {
  final String cicloAlumno;
  const PerfilTab({super.key, required this.cicloAlumno});

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  static const List<String> grados = [
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

  Future<void> _mostrarDialogoEdicion(String actual) async {
    String seleccionado = actual;
    if (!grados.contains(seleccionado)) {
      seleccionado = grados.first;
    }
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Modificar perfil'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF333333),
                value: seleccionado,
                items: grados
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => seleccionado = v);
                },
                decoration: const InputDecoration(labelText: 'Grado'),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(user.uid)
                      .update({'ciclo': seleccionado});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Grado actualizado.')),
                    );
                  }
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('No hay usuario autenticado.'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error cargando perfil.'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final nombre = data['nombre'] ?? 'Sin nombre';
        final correo = data['email'] ?? user.email ?? 'Sin correo';
        final grado = data['ciclo'] ?? 'Sin grado';

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mi perfil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                ),
              ),
              const SizedBox(height: 16),
              Text('Nombre: $nombre', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Correo: $correo', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Grado: $grado', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _mostrarDialogoEdicion(grado),
                child: const Text('Cambiar Grado'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 4. PESTAÑA OFERTAS
// ==========================================
class ListaOfertasTab extends StatefulWidget {
  final String cicloAlumno;
  const ListaOfertasTab({super.key, required this.cicloAlumno});

  @override
  State<ListaOfertasTab> createState() => _ListaOfertasTabState();
}

class _ListaOfertasTabState extends State<ListaOfertasTab> {
  late Stream<QuerySnapshot> _ofertasStream;

  @override
  void initState() {
    super.initState();
    _actualizarStream();
  }

  void _actualizarStream() {
    _ofertasStream = FirebaseFirestore.instance
        .collection('ofertas')
        .where('target_ciclos', arrayContains: widget.cicloAlumno)
        .where('activa', isEqualTo: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _ofertasStream,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No hay ofertas activas."));

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _actualizarStream();
            });
          },
          child: ListView(
            children: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(8),
                color: const Color(0xFF1E1E1E),
                child: ListTile(
                  title: Text(
                    data['titulo'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  subtitle: Text(data['empresa'] ?? ''),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleOfertaScreen(data: data),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ==========================================
// 5. PESTAÑA EVENTOS
// ==========================================
class ListaEventosTab extends StatefulWidget {
  const ListaEventosTab({super.key});

  @override
  State<ListaEventosTab> createState() => _ListaEventosTabState();
}

class _ListaEventosTabState extends State<ListaEventosTab> {
  late Stream<QuerySnapshot> _eventosStream;

  @override
  void initState() {
    super.initState();
    _eventosStream = FirebaseFirestore.instance
        .collection('eventos')
        .orderBy('fecha', descending: false)
        .snapshots();
  }

  Future<void> _toggleAsistencia(String eventoId, bool asistir) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventoRef = FirebaseFirestore.instance.collection('eventos').doc(eventoId);
    final attendeeRef = eventoRef.collection('attendees').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(eventoRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final asistentesUsuarios = List<String>.from(data['asistentes_usuarios'] ?? []);

      if (asistir) {
        if (!asistentesUsuarios.contains(user.uid)) {
          asistentesUsuarios.add(user.uid);
        }
        tx.set(attendeeRef, {
          'userName': user.email?.split('@')[0] ?? 'Usuario',
          'joinedAt': FieldValue.serverTimestamp(),
        });
      } else {
        asistentesUsuarios.remove(user.uid);
        tx.delete(attendeeRef);
      }

      tx.update(eventoRef, {
        'asistentes_usuarios': asistentesUsuarios,
        'asistentes': asistentesUsuarios.length,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _eventosStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No hay eventos programados."));

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _eventosStream = FirebaseFirestore.instance
                  .collection('eventos')
                  .orderBy('fecha', descending: false)
                  .snapshots();
            });
          },
          child: ListView(
            children: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              final currentUser = FirebaseAuth.instance.currentUser;
              final asistentesUsuarios = List<String>.from(data['asistentes_usuarios'] ?? []);
              final asistentesCount = (data['asistentes'] is num ? (data['asistentes'] as num).toInt() : asistentesUsuarios.length);
              final isAsistiendo = currentUser != null && asistentesUsuarios.contains(currentUser.uid);

              String fechaBonita = 'Fecha pendiente';
              if (data['fecha'] != null) {
                if (data['fecha'] is Timestamp) {
                  final dateTime = (data['fecha'] as Timestamp).toDate();
                  fechaBonita = "${dateTime.day}/${dateTime.month}/${dateTime.year}";
                } else {
                  fechaBonita = data['fecha'].toString();
                }
              }

              return Card(
                margin: const EdgeInsets.all(10),
                color: const Color(0xFF222222),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.purpleAccent, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['titulo'] ?? 'Evento',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 18, color: Colors.cyanAccent),
                          const SizedBox(width: 8),
                          Text(data['ponente'] ?? 'Por definir', style: const TextStyle(color: Colors.cyanAccent)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(fechaBonita, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: isAsistiendo,
                            onChanged: (valor) {
                              if (valor != null) _toggleAsistencia(doc.id, valor);
                            },
                            activeColor: Colors.cyanAccent,
                          ),
                          const Expanded(child: Text("Asistiré a este evento")),
                          Text('$asistentesCount asistentes', style: const TextStyle(color: Colors.purpleAccent)),
                        ],
                      ),
                      if (isAsistiendo)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                            icon: const Icon(Icons.chat),
                            label: const Text("ENTRAR AL CHAT DEL EVENTO"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    eventId: doc.id,
                                    userId: currentUser!.uid,
                                    userName: currentUser.email?.split('@')[0] ?? 'Usuario',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const Divider(),
                      Text(data['descripcion'] ?? 'Sin descripción'),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ==========================================
// 6. DETALLE OFERTA
// ==========================================
class DetalleOfertaScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const DetalleOfertaScreen({super.key, required this.data});

  Future<void> _abrirEnlace(BuildContext context, String link) async {
    if (link.isEmpty) return;
    Uri uri = link.contains('@') ? Uri(scheme: 'mailto', path: link) : Uri.parse(link.startsWith('http') ? link : 'https://$link');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(data['titulo'])),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['titulo'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            Text(data['empresa'], style: const TextStyle(fontSize: 18, color: Colors.white70)),
            const Divider(),
            Expanded(child: SingleChildScrollView(child: Text(data['descripcion'] ?? ''))),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text("CONTACTAR"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: () => _abrirEnlace(context, data['link'] ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
