import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Inicializar permisos y obtener token
  static Future<void> initialize() async {
    if (kIsWeb) {
      await _initializeWeb();
      return;
    }
    
    await _initializeMobile();
  }

  // Configurar handler para mensajes en segundo plano
  static void setupBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  // Manejar mensajes cuando la app está en segundo plano
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Mensaje recibido en segundo plano: ${message.notification?.title}');
    print('Datos: ${message.data}');
  }

  // Inicialización para web
  static Future<void> _initializeWeb() async {
    try {
      // Configuración para web sin clave VAPID específica
      final messaging = FirebaseMessaging.instance;
      
      // Solicitar permisos para notificaciones en web
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: true,
        criticalAlert: true,
        provisional: true,
        sound: true,
      );

      print('Estado de permisos web: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Obtener token FCM para web
        String? token = await messaging.getToken();
        
        print('Token FCM obtenido: ${token != null ? "Sí" : "No"}');
        
        if (token != null) {
          await _guardarTokenFCM(token);
        }

        // Suscribir a temas
        await _suscribirATemas();
      }
    } catch (e) {
      print('Error inicializando notificaciones web: $e');
    }
  }

  // Inicialización para mobile
  static Future<void> _initializeMobile() async {
    try {
      // Configurar handler de segundo plano
      setupBackgroundHandler();
      
      // Obtener token inicial
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('Token FCM: $token');
        await _guardarTokenFCM(token);
      }

      // Suscribir a temas
      await _suscribirATemas();

      // Manejar cuando la app se abre desde una notificación
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Verificar si hay mensaje inicial (app была cerrada)
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } catch (e) {
      print('Error inicializando notificaciones mobile: $e');
    }
  }

  // Manejar cuando el usuario toca la notificación
  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('Notificación tocada: ${message.notification?.title}');
    
    final data = message.data;
    final tipo = data['tipo'];
    
    if (tipo == 'evento') {
      print('Navegar a evento: ${data['eventoId']}');
    } else if (tipo == 'oferta') {
      print('Navegar a oferta: ${data['ofertaId']}');
    }
  }

  // Guardar token FCM en Firestore
  static Future<void> _guardarTokenFCM(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'tokenActualizado': FieldValue.serverTimestamp(),
      });
    }
  }

  // Suscribir al usuario a temas basados en su ciclo
  static Future<void> _suscribirATemas() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Obtener el ciclo del usuario
    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      final ciclo = userDoc.data()!['ciclo'] as String?;
      if (ciclo != null) {
        // Suscribir al tema del ciclo específico
        String topicName = _normalizarTopic(ciclo);
        await _firebaseMessaging.subscribeToTopic(topicName);

        // También suscribir a tema general de ofertas
        await _firebaseMessaging.subscribeToTopic('ofertas');
      }
    }

    // Suscribir a tema general de eventos
    await _firebaseMessaging.subscribeToTopic('eventos');
  }

  // Normalizar nombre para topic de Firebase
  static String _normalizarTopic(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_\$'), '');
  }

  // Actualizar suscripción cuando cambia el ciclo del usuario
  static Future<void> actualizarSuscripcionCiclo(String nuevoCiclo) async {
    // Primero obtener el ciclo anterior del usuario
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      final cicloAnterior = userDoc.data()!['ciclo'] as String?;
      
      // Darse de baja del tema anterior
      if (cicloAnterior != null && cicloAnterior != nuevoCiclo) {
        String topicAnterior = _normalizarTopic(cicloAnterior);
        await _firebaseMessaging.unsubscribeFromTopic(topicAnterior);
      }

      // Suscribirse al nuevo tema
      String topicNuevo = _normalizarTopic(nuevoCiclo);
      await _firebaseMessaging.subscribeToTopic(topicNuevo);
    }
  }

  // Obtener token actual
  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  // Eliminar token al cerrar sesión
  static Future<void> eliminarToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'fcmToken': FieldValue.delete(),
      });
    }
  }
}