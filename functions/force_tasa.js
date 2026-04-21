const admin = require('firebase-admin');
admin.initializeApp();

async function updateTasa() {
    try {
        const db = admin.firestore();
        await db.collection('configuracion').doc('tasa_cambio').set({
            bcv: 433.17,
            fuente: "node_script_manual",
            ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log("Tasa BCV actualizada exitosamente en Firestore a 433.17");
        process.exit(0);
    } catch (e) {
        console.error("Error actualizando Firestore:", e);
        process.exit(1);
    }
}

updateTasa();
