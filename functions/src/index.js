const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// ==========================================
// NOTIFICACIONES DE EVENTOS
// ==========================================
exports.notificarNuevoEvento = functions.firestore
  .document('eventos/{eventoId}')
  .onCreate(async (snap, context) => {
    const eventoData = snap.data();
    const eventoId = context.params.eventoId;

    // Título y datos del evento
    const titulo = eventoData.titulo || 'Nuevo evento';
    const descripcion = eventoData.descripcion || 'Se ha publicado un nuevo evento';

    // Mensaje para tema de eventos
    const mensajeEvento = {
      notification: {
        title: '📅 Nuevo Evento',
        body: titulo,
      },
      topic: 'eventos',
      data: {
        tipo: 'evento',
        eventoId: eventoId,
        click_action: 'OPEN_EVENTO',
      },
    };

    // Enviar a todos los suscriptores del tema eventos
    return admin.messaging().send(mensajeEvento)
      .then((response) => {
        console.log('Notificación de evento enviada:', response);
        return null;
      })
      .catch((error) => {
        console.log('Error enviando notificación de evento:', error);
        return null;
      });
  });

// ==========================================
// NOTIFICACIONES DE OFERTAS POR CICLO
// ==========================================
exports.notificarNuevaOferta = functions.firestore
  .document('ofertas/{ofertaId}')
  .onCreate(async (snap, context) => {
    const ofertaData = snap.data();
    const ofertaId = context.params.ofertaId;

    const titulo = ofertaData.titulo || 'Nueva oferta de empleo';
    const empresa = ofertaData.empresa || '';
    const targetCiclos = ofertaData.target_ciclos || [];

    // 1. Notificación a tema general de ofertas
    const mensajeGeneral = {
      notification: {
        title: '💼 Nueva Oferta de Empleo',
        body: `${titulo} - ${empresa}`,
      },
      topic: 'ofertas',
      data: {
        tipo: 'oferta',
        ofertaId: ofertaId,
        click_action: 'OPEN_OFERTA',
      },
    };

    // 2. Notificaciones por cada ciclo específico
    const promesasEnvio = [];

    // Enviar a tema general
    promesasEnvio.push(
      admin.messaging().send(mensajeGeneral).catch((error) => {
        console.log('Error enviando a tema ofertas:', error);
      })
    );

    // Enviar a cada ciclo específico
    for (const ciclo of targetCiclos) {
      const topicCiclo = normalizarTopic(ciclo);
      
      const mensajeCiclo = {
        notification: {
          title: `💼 Oferta para ${ciclo}`,
          body: `${titulo} - ${empresa}`,
        },
        topic: topicCiclo,
        data: {
          tipo: 'oferta',
          ofertaId: ofertaId,
          ciclo: ciclo,
          click_action: 'OPEN_OFERTA',
        },
      };

      promesasEnvio.push(
        admin.messaging().send(mensajeCiclo).catch((error) => {
          console.log(`Error enviando a tema ${topicCiclo}:`, error);
        })
      );
    }

    return Promise.all(promesasEnvio);
  });

// ==========================================
// NOTIFICACIONES PERSONALIZADAS (Por usuario)
// ==========================================
exports.notificarOfertaUsuario = functions.firestore
  .document('ofertas/{ofertaId}')
  .onCreate(async (snap, context) => {
    const ofertaData = snap.data();
    const ofertaId = context.params.ofertaId;
    const targetCiclos = ofertaData.target_ciclos || [];

    if (targetCiclos.length === 0) return null;

    // Buscar usuarios suscritos a estos ciclos
    const usuariosSnapshot = await admin.firestore()
      .collection('usuarios')
      .where('ciclo', 'in', targetCiclos)
      .get();

    if (usuariosSnapshot.empty) return null;

    // Recopilar tokens FCM de usuarios
    const tokens = [];
    usuariosSnapshot.forEach((doc) => {
      const userData = doc.data();
      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    });

    if (tokens.length === 0) return null;

    // Enviar notificación a cada token
    const titulo = ofertaData.titulo || 'Nueva oferta';
    const empresa = ofertaData.empresa || '';

    const payload = {
      notification: {
        title: '🎯 Oferta dirigida a tu ciclo',
        body: `${titulo} - ${empresa}`,
      },
      data: {
        tipo: 'oferta',
        ofertaId: ofertaId,
        click_action: 'OPEN_OFERTA',
      },
    };

    // Dividir tokens en batches de 500 (límite de FCM)
    const batches = [];
    for (let i = 0; i < tokens.length; i += 500) {
      batches.push(tokens.slice(i, i + 500));
    }

    const promises = batches.map((batch) => 
      admin.messaging().sendToDevice(batch, payload).catch((error) => {
        console.log('Error enviando a dispositivos:', error);
      })
    );

    return Promise.all(promises);
  });

// ==========================================
// FUNCION AUXILIAR: Normalizar nombre para topic
// ==========================================
function normalizarTopic(texto) {
  if (!texto) return 'general';
  return texto
    .toLowerCase()
    .replaceAll(/[^a-z0-9]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');
}