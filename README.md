# Interfajas (app móvil)

App en Flutter del proyecto de grado: gestión de arreglos de fajas de
Interfajas, con mapa de domicilios. Usa lo mismo que el curso:

| Lo de la clase (FET Campus)          | En Interfajas                                      |
|--------------------------------------|----------------------------------------------------|
| Login real con Firebase Auth         | Login, registro y recuperar contraseña             |
| AuthGate (sesión persistente)        | Igual                                              |
| Firestore `usuarios/{uid}/tareas`    | `usuarios/{uid}/clientes, arreglos, pagos, recordatorios, ajustes` |
| Reglas por usuario                   | Las mismas reglas (`firestore.rules`)              |
| flutter_map + OpenStreetMap          | Mapa de domicilios y selector de la casa del cliente |
| geolocator (permiso, punto azul)     | Igual                                              |
| Marcar puntos en Firestore           | La casa de cada cliente y el taller                |
| Cómo llegar (OSRM), desvío, ¡Llegaste! | Ruta hasta el cliente + botón "Entregado"        |

## De MySQL a Firestore

| Tabla MySQL (`taller_arreglos`) | Firestore (dentro de `usuarios/{uid}/`) |
|---------------------------------|-----------------------------------------|
| usuarios / roles                | Firebase Authentication (cada cuenta = un taller) |
| clientes                        | `clientes/{id}`: nombre, telefono, correo, direccion, lat, lng |
| arreglos                        | `arreglos/{id}`: idCliente, nombreCliente, tipo, descripcion, estado, fechaIngreso, fechaEntrega, valor, domicilio |
| estados                         | enum `EstadoArreglo` (Recibido, En proceso, Listo, Entregado) |
| pagos                           | `pagos/{id}`: idArreglo, monto, tipo, fecha |
| tipo_pago                       | enum `TipoPago` (Efectivo, Nequi, Transferencia, Tarjeta) |
| recordatorios                   | `recordatorios/{id}`: titulo, fecha, hora, minuto, color, hecho |
| (nuevo)                         | `ajustes/taller`: lat, lng del taller |

## Pestañas
- **Inicio**: panel con pendientes, listos, domicilios, por cobrar e ingresos del mes por tipo de pago.
- **Arreglos**: lista con filtro por estado; detalle con cambio de estado, pagos (abonos) y saldo.
- **Clientes**: buscador; formulario con la casa marcada en el mapa.
- **Agenda**: por día, entregas y recordatorios.
- **Domicilios**: mapa con el taller, las casas con domicilio pendiente (color = estado), tu ubicación, ruta y "Entregado".

## Puesta en marcha
1. Crea un proyecto nuevo en https://console.firebase.google.com (ej. `interfajas-app`).
   - Authentication → Correo electrónico/contraseña → Habilitar.
   - Firestore Database → Crear base de datos → modo de producción.
   - Firestore → Reglas → pega `firestore.rules` → Publicar.
2. En la terminal, dentro de esta carpeta: `bash preparar.sh`
3. `flutterfire configure` → elige el proyecto nuevo (ios, android, web).
4. `flutter run` (iPhone o simulador).
