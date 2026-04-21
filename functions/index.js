const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

// Inicializar Firebase Admin
admin.initializeApp();
const db = admin.database();

// Limitar instancias para ahorrar costos
setGlobalOptions({maxInstances: 10, region: "us-central1"});

/**
 * Configuración de Mercantil
 *aqui van los datos de mercantil en produccion
 */
const MERCANTIL_CONFIG = {
  merchantId: "TU_MERCHANT_ID",
  terminalId: "1",
  clientId: "TU_CLIENT_ID",
  encryptKey: "TU_ENCRYPT_KEY",
};

exports.procesarPagoC2P = onCall(async (request) => {
  // Verificar autenticación
  if (!request.auth) {
    throw new HttpsError("Usuario no autorizado.");
  }

  const {monto, cedula, telefono, banco, claveC2P, tipo} = request.data;
  const uid = request.auth.uid;

  if (!monto || !cedula || !telefono || !claveC2P) {
    throw new HttpsError("invalid-argument", "Faltan datos requeridos.");
  }

  // --- MOCK INICIO: SOLO PARA DESARROLLO ---
  if (claveC2P === "123456") {
    try {
      let nodoBase = "usuarios";
      if (tipo === "recarga_pasajero" || tipo === "pasajero") {
        nodoBase = "pasajeros";
      }

      const pathBilletera = `${nodoBase}/${uid}/billetera`;
      const saldoRef = db.ref(`${pathBilletera}/saldo`);

      await saldoRef.transaction((currentValue) => {
        return (parseFloat(currentValue) || 0) + parseFloat(monto);
      });

      await db.ref(`${pathBilletera}/actividad`).push({
        monto: parseFloat(monto),
        tipo: tipo || "recarga_c2p",
        fecha: admin.database.ServerValue.timestamp,
        referencia: "MOCK-" + Date.now(),
        status: "completado",
      });

      return {success: true, data: { status: "completado_mock" }};
    } catch (e) {
      console.error("Error mock procesarPagoC2P:", e);
      throw new HttpsError("internal", "Error en mock.");
    }
  }
  // --- MOCK FIN ---

  const payload = {
    merchant_identify: {
      integratorId: 1,
      merchantId: parseInt(MERCANTIL_CONFIG.merchantId),
      terminalId: parseInt(MERCANTIL_CONFIG.terminalId),
    },
    payment_method: "c2p",
    transaction: {
      amount: parseFloat(monto),
      currency: "ves",
      destination_id: cedula,
      destination_mobile_number: telefono,
      destination_bank_id: banco || "0105",
      payment_reference: claveC2P,
    },
  };

  try {
    // LLAMADA AL BANCO
    const res = await axios.post(
        "https://apimbu.mercantilbanco.com/mercantil-banco/prod/v1/payment/c2p",
        payload,
        {
          headers: {
            "Content-Type": "application/json",
            "X-IBM-Client-Id": MERCANTIL_CONFIG.clientId,
          },
        },
    );

    // Si la operación fue exitosa en el banco, actualizamos Firebase
    // Nota: Ajustar según la respuesta real de Mercantil
    if (res.status === 200 || res.status === 201) {
      // Determinar nodo base según tipo (defecto: usuarios para conductores)
      let nodoBase = "usuarios";
      if (tipo === "recarga_pasajero" || tipo === "pasajero") {
        nodoBase = "pasajeros";
      } else if (tipo === "recarga_conductor" || tipo === "conductor") {
        nodoBase = "usuarios";
      }

      const pathBilletera = `${nodoBase}/${uid}/billetera`;
      const saldoRef = db.ref(`${pathBilletera}/saldo`);

      // Incremento atómico del saldo
      await saldoRef.transaction((currentValue) => {
        return (parseFloat(currentValue) || 0) + parseFloat(monto);
      });

      // Registro de la transacción
      await db.ref(`${pathBilletera}/actividad`).push({
        monto: parseFloat(monto),
        tipo: tipo || "recarga_c2p",
        fecha: admin.database.ServerValue.timestamp,
        referencia: claveC2P,
        status: "completado",
      });

      return {success: true, data: res.data};
    } else {
      return {success: false, error: "Error en respuesta del banco"};
    }
  } catch (error) {
    console.error("Error en procesarPagoC2P:", error.message);
    return {
      success: false,
      error: error.response ? error.response.data : error.message,
    };
  }
});

// =============================================================================
// CLOUD FUNCTIONS PARA NOTIFICACIONES FCM - VIAJES PROGRAMADOS
// =============================================================================

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onValueCreated} = require("firebase-functions/v2/database");

/**
 * Función para enviar notificación FCM a un dispositivo
 * @param {string} token - FCM Token del dispositivo
 * @param {Object} notification - Datos de la notificación
 * @param {Object} data - Datos adicionales para la app
 * @return {Promise<Object>} Resultado del envío
 */
async function enviarNotificacionFCM(token, notification, data = {}) {
  if (!token) {
    console.error("Token FCM no proporcionado");
    return {success: false, error: "Token no proporcionado"};
  }

  const message = {
    token: token,
    notification: notification,
    data: {
      ...data,
      timestamp: Date.now().toString(),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "viajes_programados_channel",
        priority: "high",
        sound: "default",
        vibrateTimings: ["0s", "0.5s", "0.5s"],
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          alert: notification,
        },
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("Notificación enviada exitosamente:", response);
    return {success: true, messageId: response};
  } catch (error) {
    console.error("Error enviando notificación:", error);
    return {success: false, error: error.message};
  }
}

/**
 * Cloud Function que se ejecuta cada minuto para verificar y enviar
 * notificaciones programadas de viajes
 */
exports.procesarNotificacionesProgramadas = onSchedule({
  schedule: "every 1 minutes",
  region: "us-central1",
  maxInstances: 1,
}, async (event) => {
  const ahora = Date.now();
  console.log("Ejecutando procesamiento de notificaciones:", new Date(ahora));

  try {
    // Buscar notificaciones pendientes cuya fecha de notificación ya pasó
    const notificacionesRef = db.ref("notificaciones_programadas");
    const snapshot = await notificacionesRef
        .orderByChild("estado")
        .equalTo("pendiente")
        .once("value");

    if (!snapshot.exists()) {
      console.log("No hay notificaciones pendientes");
      return null;
    }

    const notificaciones = snapshot.val();
    const promesas = [];

    for (const [notificacionId, notificacion] of
      Object.entries(notificaciones)) {
      const fechaNotificacion = notificacion.fechaHoraNotificacion;

      // Si la hora de notificación ya pasó
      if (fechaNotificacion && fechaNotificacion <= ahora) {
        console.log(`Procesando notificación ${notificacionId}`);

        promesas.push(
            procesarNotificacionIndividual(notificacionId, notificacion, ahora),
        );
      }
    }

    if (promesas.length > 0) {
      await Promise.all(promesas);
      console.log(`Procesadas ${promesas.length} notificaciones`);
    }

    return null;
  } catch (error) {
    console.error("Error en procesarNotificacionesProgramadas:", error);
    return null;
  }
});

/**
 * Procesa una notificación individual
 * @param {string} notificacionId - ID de la notificación
 * @param {Object} notificacion - Datos de la notificación
 * @param {number} ahora - Timestamp actual
 * @return {Promise<void>}
 */
async function procesarNotificacionIndividual(
    notificacionId, notificacion, ahora) {
  const {viajeId, conductorId, tipoNotificacion, titulo, mensaje, data} =
    notificacion;

  try {
    // Obtener el token FCM del conductor
    const conductorRef = db.ref(`usuarios/${conductorId}/fcmToken`);
    const tokenSnapshot = await conductorRef.once("value");
    const fcmToken = tokenSnapshot.val();

    if (!fcmToken) {
      console.warn(`Conductor ${conductorId} no tiene token FCM registrado`);

      // Marcar como fallida
      await db.ref(`notificaciones_programadas/${notificacionId}`).update({
        estado: "fallida",
        error: "Token FCM no encontrado",
        procesadoEn: ahora,
      });

      return;
    }

    // Preparar la notificación según el tipo
    const notification = {
      title: titulo || "Viaje Programado",
      body: mensaje || "Tienes un viaje programado próximamente",
    };

    const notificationData = {
      viajeId: viajeId || "",
      tipo: tipoNotificacion || "recordatorio",
      conductorId: conductorId || "",
      ...data,
    };

    // Ajustar mensaje según el tipo
    if (tipoNotificacion === "recordatorio_1hora") {
      notification.title = "🚗 Viaje Programado - En 1 Hora";
      notification.body = mensaje ||
        "Tu viaje programado comienza en 1 hora. Prepárate!";
      notificationData.tipo = "recordatorio_1hora";
    } else if (tipoNotificacion === "recordatorio_20min") {
      notification.title = "⏰ Viaje Programado - En 20 Minutos";
      notification.body = mensaje ||
        "¡Tu viaje está por comenzar! Ve hacia el punto de encuentro.";
      notificationData.tipo = "recordatorio_20min";
    } else if (tipoNotificacion === "viaje_cancelado") {
      notification.title = "❌ Viaje Cancelado";
      notification.body = mensaje ||
        "El pasajero ha cancelado el viaje programado.";
      notificationData.tipo = "viaje_cancelado";
    } else if (tipoNotificacion === "nueva_asignacion") {
      notification.title = "📍 Nuevo Viaje Programado Asignado";
      notification.body = mensaje ||
        "Se te ha asignado un nuevo viaje programado.";
      notificationData.tipo = "nueva_asignacion";
    }

    // Enviar la notificación
    const resultado = await enviarNotificacionFCM(
        fcmToken,
        notification,
        notificationData,
    );

    if (resultado.success) {
      // Marcar como enviada
      await db.ref(`notificaciones_programadas/${notificacionId}`).update({
        estado: "enviada",
        enviadoEn: ahora,
        messageId: resultado.messageId,
      });

      // Actualizar el campo notificacionEnviada en el viaje programado
      if (viajeId) {
        await db.ref(`viajes_programados/${viajeId}`).update({
          notificacionEnviada: true,
          fechaHoraNotificacion: ahora,
        });
      }

      console.log(`Notificación ${notificacionId} enviada exitosamente`);
    } else {
      // Marcar como fallida
      await db.ref(`notificaciones_programadas/${notificacionId}`).update({
        estado: "fallida",
        error: resultado.error,
        procesadoEn: ahora,
      });

      console.error("Error enviando notificación " + notificacionId + ":",
          resultado.error);
    }
  } catch (error) {
    console.error(`Error procesando notificación ${notificacionId}:`, error);

    // Marcar como fallida
    await db.ref(`notificaciones_programadas/${notificacionId}`).update({
      estado: "fallida",
      error: error.message,
      procesadoEn: ahora,
    });
  }
}

/**
 * Cloud Function que se ejecuta cuando se crea una nueva
 * notificación programada. Útil para notificaciones inmediatas
 */
exports.onNotificacionCreada = onValueCreated({
  ref: "/notificaciones_programadas/{notificacionId}",
  region: "us-central1",
}, async (event) => {
  const notificacion = event.data.val();
  const notificacionId = event.params.notificacionId;

  if (!notificacion) {
    console.log("Notificación vacía");
    return null;
  }

  // Si la notificación es para enviarse inmediatamente
  const ahora = Date.now();
  const fechaNotificacion = notificacion.fechaHoraNotificacion || ahora;

  if (notificacion.estado === "pendiente" && fechaNotificacion <= ahora) {
    console.log(`Procesando notificación inmediata: ${notificacionId}`);
    await procesarNotificacionIndividual(notificacionId, notificacion, ahora);
  }

  return null;
});

/**
 * Cloud Function para enviar notificación inmediata
 * (llamada manual o desde cliente)
 */
exports.enviarNotificacionInmediata = onCall({
  region: "us-central1",
  maxInstances: 10,
}, async (request) => {
  // Verificar autenticación
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Usuario no autorizado.");
  }

  const {conductorId, titulo, mensaje, data} = request.data;

  if (!conductorId || !titulo || !mensaje) {
    throw new HttpsError(
        "invalid-argument",
        "Faltan datos requeridos: conductorId, titulo, mensaje",
    );
  }

  try {
    // Obtener el token FCM del conductor
    const conductorRef = db.ref(`usuarios/${conductorId}/fcmToken`);
    const tokenSnapshot = await conductorRef.once("value");
    const fcmToken = tokenSnapshot.val();

    if (!fcmToken) {
      return {
        success: false,
        error: "El conductor no tiene token FCM registrado",
      };
    }

    const notification = {
      title: titulo,
      body: mensaje,
    };

    const notificationData = {
      tipo: "notificacion_manual",
      timestamp: Date.now().toString(),
      ...data,
    };

    const resultado = await enviarNotificacionFCM(
        fcmToken,
        notification,
        notificationData,
    );

    // Registrar la notificación enviada
    await db.ref("notificaciones_enviadas").push({
      conductorId,
      titulo,
      mensaje,
      enviadoPor: request.auth.uid,
      enviadoEn: admin.database.ServerValue.timestamp,
      exito: resultado.success,
      error: resultado.error || null,
    });

    return resultado;
  } catch (error) {
    console.error("Error en enviarNotificacionInmediata:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Cloud Function para registrar/revovar token FCM de un usuario
 */
exports.registrarTokenFCM = onCall({
  region: "us-central1",
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Usuario no autorizado.");
  }

  const {token, tipoUsuario} = request.data;

  if (!token) {
    throw new HttpsError("invalid-argument", "Token FCM requerido");
  }

  const uid = request.auth.uid;
  const nodoBase = tipoUsuario === "pasajero" ? "pasajeros" : "usuarios";

  try {
    await db.ref(`${nodoBase}/${uid}`).update({
      fcmToken: token,
      fcmTokenActualizadoEn: admin.database.ServerValue.timestamp,
      plataforma: request.data.plataforma || "unknown",
    });

    console.log(`Token FCM registrado para ${uid}`);
    return {success: true, message: "Token registrado exitosamente"};
  } catch (error) {
    console.error("Error registrando token FCM:", error);
    throw new HttpsError("internal", error.message);
  }
});
