import 'package:cloud_firestore/cloud_firestore.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Inscribir al usuario (Punto clave para que el chat lo deje pasar)
  Future<void> registerForEvent(String eventId, String userId, String userName) async {
    await _db
        .collection('events')
        .doc(eventId)
        .collection('attendees')
        .doc(userId)
        .set({
      'userName': userName,
      'registeredAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. Verificar si ya está inscrito
  Future<bool> checkIfRegistered(String eventId, String userId) async {
    final doc = await _db
        .collection('events')
        .doc(eventId)
        .collection('attendees')
        .doc(userId)
        .get();
    return doc.exists;
  }
}