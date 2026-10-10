# Privacidad

**Estado 2026-10-07:** CSV/JSON retirados también de Flutter. Se conservan datos importados y backup cifrado; ver [entrega](IMPLEMENTATION_PLAN.md#traslado-autorizado-a-flutter--2026-10-07).

Cabal está diseñada para funcionar sin cuenta, servidor, anuncios, analytics ni crash reporting remoto. La base vive en el sandbox privado de Android y el manifest desactiva backup automático y tráfico HTTP sin cifrar. Las funciones centrales no necesitan Internet.

## Datos y permisos

- `USE_BIOMETRIC`: opcional, para biometría o credencial del dispositivo mediante `local_auth`; no se guarda un PIN propio.
- Acceso especial a notificaciones: opcional y revocable en Ajustes de Android. No es un permiso SMS y la app nunca accede a la bandeja de mensajes.
- `POST_NOTIFICATIONS`: opcional en Android 13+, para emitir notificaciones locales del simulador de desarrollo; no se emiten avisos de revisión de compras.
- Storage Access Framework: el usuario elige el destino del backup o el archivo a restaurar.

Wallet y el registro automático están en Más → Google Wallet, desactivados inicialmente. El listener permanece pausado hasta que el usuario habilita Wallet y concede acceso en Android. SMS, diagnóstico, inspección manual y simulador permanecen en desarrollo y bloqueados en release/profile. Solo acepta la lista visible de paquetes configurados. La cola nativa guarda temporalmente el contenido de notificaciones cifrado con AES-GCM en almacenamiento privado; Android Keystore protege la clave. La base activa y WAL usan SQLite3MultipleCiphers. Esta descripción proviene de inspección, no de una auditoría criptográfica ni validación integral de Keystore en teléfono. Ver [arquitectura](ARCHITECTURE.md). Al procesarlas, la base no conserva el texto completo salvo que esté activado el diagnóstico de desarrollo. Los eventos vencen a las 24 horas y se limpian al abrir o procesar; no hay eliminación programada con la app cerrada. Se pueden borrar manualmente y la exportación de diagnóstico se sanitiza. OTP se ignora. Con el registro automático activado explícitamente, compras reconocidas con cuenta y comercio únicos pueden afectar saldos al procesar la cola; casos desconocidos o dudosos requieren confirmación.

Los backups manuales incluyen la base completa y están cifrados con una contraseña elegida por el usuario. La contraseña no se persiste y no puede recuperarse. El selector puede ofrecer proveedores externos; el usuario elige el destino. No hay exportaciones financieras legibles CSV/JSON en el producto.

## Divulgación preliminar para Google Play

> Cabal procesa datos financieros y, si el usuario lo habilita, contenido de notificaciones seleccionadas exclusivamente en el dispositivo para proponer movimientos. No vende ni comparte estos datos y no opera un servidor propio. El acceso puede pausarse o revocarse, y el registro automático de compras reconocidas es opcional y está desactivado inicialmente.

Este texto es una preparación técnica, no una afirmación de cumplimiento. Debe revisarse contra la versión publicada, la ficha Data Safety y las políticas vigentes antes de distribuir.

