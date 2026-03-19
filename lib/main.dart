import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

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
        primaryColor: Colors.cyanAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.black,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
      ),
      // CAMBIO: Ahora la pantalla inicial es el Login
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
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Buscamos el ciclo del usuario
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(cred.user!.uid)
          .get();
      if (!doc.exists) throw Exception("Usuario sin perfil");

      final ciclo = doc.get('ciclo');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaPrincipal(cicloAlumno: ciclo),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 20),
              const Text(
                "Bolsa SGema",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Contraseña"),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(15),
                        ),
                        onPressed: _iniciarSesion,
                        child: const Text("ENTRAR"),
                      ),
                    ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegistroScreen()),
                ),
                child: const Text(
                  "Crear cuenta",
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. REGISTRO
// ==========================================
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  String _ciclo = 'DAM';
  bool _isLoading = false;

  Future<void> _registrarse() async {
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(cred.user!.uid)
          .set({
            'nombre': _nombreController.text.trim(),
            'email': _emailController.text.trim(),
            'ciclo': _ciclo,
            'fecha_registro': DateTime.now(),
          });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaPrincipal(cicloAlumno: _ciclo),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Contraseña"),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: _ciclo,
              items: ['DAM', 'DAW', 'ASIR', 'SMR']
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              dropdownColor: const Color(0xFF333333),
              onChanged: (v) => setState(() => _ciclo = v!),
              decoration: const InputDecoration(labelText: "Ciclo"),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(15),
                      ),
                      onPressed: _registrarse,
                      child: const Text("REGISTRARME"),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. PANTALLA PRINCIPAL (CON PESTAÑAS) - NUEVO
// ==========================================
class PantallaPrincipal extends StatefulWidget {
  final String cicloAlumno;
  const PantallaPrincipal({super.key, required this.cicloAlumno});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0; // 0 = Ofertas, 1 = Agenda

  @override
  Widget build(BuildContext context) {
    // Lista de pantallas para cambiar
    final List<Widget> pantallas = [
      ListaOfertasTab(cicloAlumno: widget.cicloAlumno), // Pestaña 0
      const ListaEventosTab(), // Pestaña 1
    ];

    return Scaffold(
      // AppBar dinámico según la pestaña
      appBar: AppBar(
        title: Text(
          _indiceActual == 0
              ? 'Ofertas ${widget.cicloAlumno} 💼'
              : 'Agenda Eventos 📅',
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
        ],
      ),
    );
  }
}

// ==========================================
// 4. PESTAÑA OFERTAS (Antigua ListaOfertasScreen)
// ==========================================
class ListaOfertasTab extends StatelessWidget {
  final String cicloAlumno;
  const ListaOfertasTab({super.key, required this.cicloAlumno});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('ofertas')
          .where('target_ciclos', arrayContains: cicloAlumno)
          .where('activa', isEqualTo: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text("No hay ofertas activas."));

        return ListView(
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
        );
      },
    );
  }
}

// ==========================================
// 5. PESTAÑA EVENTOS (NUEVA 📅)
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
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para registrar asistencia.'),
          ),
        );
      }
      return;
    }

    final eventoRef = FirebaseFirestore.instance
        .collection('eventos')
        .doc(eventoId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(eventoRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final asistentesUsuarios = List<String>.from(
        data['asistentes_usuarios'] ?? [],
      );
      if (asistir) {
        if (!asistentesUsuarios.contains(user.uid)) {
          asistentesUsuarios.add(user.uid);
        }
      } else {
        asistentesUsuarios.remove(user.uid);
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
        // Manejo de errores
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  "Error al cargar eventos: ${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text("Reintentar"),
                ),
              ],
            ),
          );
        }

        // Cargando
        if (!snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Cargando eventos..."),
              ],
            ),
          );
        }

        // Sin eventos
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 60,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  "No hay eventos programados. 😴",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text("Actualizar"),
                ),
              ],
            ),
          );
        }

        // Listar eventos
        return RefreshIndicator(
          onRefresh: () async {
            // Forzar actualización del stream
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
              final asistentesUsuarios = List<String>.from(
                data['asistentes_usuarios'] ?? [],
              );
              final asistentesCount = (data['asistentes'] is num
                  ? (data['asistentes'] as num).toInt()
                  : asistentesUsuarios.length);
              final isAsistiendo =
                  currentUser != null &&
                  asistentesUsuarios.contains(currentUser.uid);

              // Convertir fecha
              String fechaBonita = 'Fecha pendiente';
              try {
                if (data['fecha'] != null) {
                  final fecha = data['fecha'];
                  if (fecha is String) {
                    fechaBonita = fecha;
                  } else if (fecha is Timestamp) {
                    // Convertir como Timestamp de Firestore
                    final dateTime = fecha.toDate();
                    const meses = [
                      'enero',
                      'febrero',
                      'marzo',
                      'abril',
                      'mayo',
                      'junio',
                      'julio',
                      'agosto',
                      'septiembre',
                      'octubre',
                      'noviembre',
                      'diciembre',
                    ];
                    fechaBonita =
                        '${dateTime.day} de ${meses[dateTime.month - 1]} de ${dateTime.year}';
                  }
                }
              } catch (e) {
                fechaBonita = 'Fecha no disponible';
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
                      // Título
                      Text(
                        data['titulo'] ?? 'Evento',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.purpleAccent,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Ponente
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.cyanAccent,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              data['ponente'] ?? 'Por definir',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Fecha
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              fechaBonita,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Ubicación
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              data['lugar'] ?? 'Online',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: isAsistiendo,
                            onChanged: (valor) {
                              if (valor != null) {
                                _toggleAsistencia(doc.id, valor);
                              }
                            },
                            activeColor: Colors.cyanAccent,
                          ),
                          Expanded(
                            child: Text(
                              isAsistiendo
                                  ? 'Asistiré a este evento'
                                  : 'Marcaré que voy a asistir',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$asistentesCount asistentes',
                              style: const TextStyle(
                                color: Colors.purpleAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.grey, height: 20),

                      // Descripción
                      Text(
                        data['descripcion'] ?? 'Sin descripción',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
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
    Uri uri = link.contains('@')
        ? Uri(scheme: 'mailto', path: link)
        : Uri.parse(link.startsWith('http') ? link : 'https://$link');
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
            Text(
              data['titulo'],
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),
            Text(
              data['empresa'],
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Text(data['descripcion'] ?? ''),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text("CONTACTAR"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _abrirEnlace(context, data['link'] ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
