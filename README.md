# CBRFilters

Real-time camera filter library for Adobe AIR (iOS), written in ActionScript 3.
`CBRFilters` captures the device camera feed and converts it live into **X-ray, Ultraviolet and Infrared simulated vision** (channel mixing + per-filter lookup tables), plus a **CBR mode** that turns the camera image into a light-based transparency and overlays it on a rotating Cosmic Microwave Background sphere, projected using the device accelerometer + compass. It also handles camera orientation bugs on mobile, touch-adjustable thresholds and smoothing/anti-shake controls.

**Project intent:** this library was created (2013) for **CBR**, an AIR/iOS educational app conceived as a **Cosmic Microwave Background (CBM) viewer/simulator** for cosmologist Fred Adams: an explorer of the electromagnetic spectrum where the user's own camera becomes an imaginary sensor — pointing the phone at the world and simulating how it would look under X-ray, UV or infrared vision, or placing the CBR map (ESA Planck satellite image) in the real environment through the device's orientation sensors.

> **This project is shared ONLY for educational purposes. Its use, direct or derived, for professional or economic purposes is not permitted.**

For security reasons, some parts of the project may have been edited or removed (the AIR `app-id` was anonymized; iOS signing certificates and provisioning profiles were never part of this folder).

## Using the library

Add the `.swc` (attached to release v1.0.0) to your Flash/Flash Builder advanced script settings, then:

```as3
import com.fernans.cbr.CBRFilters;

var cbr:CBRFilters = new CBRFilters();      // constructor: default 320x240 camera
addChild(cbr);                              // add to display list (shows black frame)
cbr.setFilter(CBRFilters.FILTER.XRAY);      // select / preload a filter config
cbr.setMode(CBRFilters.MODE_FULL);          // start camera + processing
cbr.setFps(true);                           // show measured FPS in a corner
```

Class constants: `MODE_NONE / MODE_VIDEO / MODE_BASIC / MODE_FULL`, filters `FILTER_NONE / FILTER_XRAY / FILTER_UV / FILTER_INFRARED / FILTER_CBR`, plus `setCBRlevel()` / `setCBRmargin()` (touch-adjustable light threshold), `setCBRImage()` (replace the CBR sphere image, square/polar format) and `offsetX/Y/Z/H`, `smooth*`, `snap*` properties for the accelerometer+compass projection. The full API reference is in [`CBRFilters_doc.txt`](CBRFilters_doc.txt) (Spanish) and [`CBRFilters_Test.as`](CBRFilters_Test.as) is a working usage example.

## Requirements / How to run

- Adobe AIR SDK 13+ (or any packager that supports AIR 13 for iOS) and Flash Professional / Flash Builder.
- **Real device required**: camera, accelerometer and compass only work on-device (iOS/Android); it will not run on the desktop player.
- For the demo in the `.fla`: open in Flash Professional with the `.swc` on the library path, publish as AIR for iOS.

No warranty of any kind is provided, and no liability is accepted for errors or damages resulting from its use of this software.

Additionally, the use of this project's content (code, documentation or assets) to train artificial intelligence or machine-learning systems is not permitted without the explicit permission of the author. Licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) — see [`LICENSE`](LICENSE).

---

# CBRFilters

Biblioteca de filtros de cámara en tiempo real para Adobe AIR (iOS), escrita en ActionScript 3.
`CBRFilters` captura la señal de la cámara del dispositivo y la convierte en vivo en **visión simulada de Rayos-X, Ultravioleta e Infrarrojos** (mezcla de canales + tablas lookup por filtro), junto a un **modo CBR** que convierte la imagen de la cámara en transparencia por luminosidad y la superpone sobre una esfera del Fondo Cósmico de Microondas, proyectada mediante el acelerómetro + brújula del dispositivo. También corrige bugs de orientación de cámara en móviles, ajuste de umbral por toque y controles de suavizado/anti-temblor.

**Intención del proyecto:** esta biblioteca se creó (2013) para **CBR**, una app educativa AIR/iOS concebida como **simulador/visor del Fondo Cósmico de Microondas (CBR)** para el cosmólogo Fred Adams: un explorador del espectro electromagnético donde la propia cámara actúa de sensor imaginario — señalando con el móvil al mundo para simular cómo se vería con visión de rayos-X, ultravioleta o infrarrojos, o situando el mapa CBR (imagen del satélite ESA Planck) en el entorno real mediante los sensores de orientación del dispositivo.

> **Este proyecto se comparte SOLO con valor educativo. No está permitido su uso (directo o derivado) para fines profesionales o económicos.**

Por motivos de seguridad, algunas partes del proyecto pueden encontrarse editadas o eliminadas (el `app-id` de AIR quedó anonimizado; los certificados/provisionings iOS nunca fueron parte de esta carpeta).

## Uso de la biblioteca

Añade el `.swc` (adjunto en el release v1.0.0) en la configuración avanzada de script de Flash/Flash Builder y:

```as3
import com.fernans.cbr.CBRFilters;

var cbr:CBRFilters = new CBRFilters();      // constructor: cámara 320x240 por defecto
addChild(cbr);                              // agregar al displayList (muestra cuadro negro)
cbr.setFilter(CBRFilters.FILTER.XRAY);      // selecciona y precarga una configuración de filtro
cbr.setMode(CBRFilters.MODE_FULL);          // activa la cámara y el proceso
cbr.setFps(true);                           // muestra los FPS medidos en una esquina
```

Constantes de clase: `MODE_NONE / MODE_VIDEO / MODE_BASIC / MODE_FULL`, filtros `FILTER_NONE / FILTER_XRAY / FILTER_UV / FILTER_INFRARED / FILTER_CBR`, más `setCBRlevel()` / `setCBRmargin()` (umbral de luz ajustable por toque), `setCBRImage()` (sustituir la imagen de la esfera CBR, formato cuadrado/polar) y las propiedades `offsetX/Y/Z/H`, `smooth*`, `snap*` para la proyección con acelerómetro+brújula. La referencia completa de la API está en [`CBRFilters_doc.txt`](CBRFilters_doc.txt) (español) y [`CBRFilters_Test.as`](CBRFilters_Test.as) es un ejemplo funcional de uso.

## Requisitos / Cómo ejecutar

- AIR SDK 13+ (o cualquier paquete que soporte AIR 13 para iOS) y Flash Professional / Flash Builder.
- **Se necesita un dispositivo real**: cámara, acelerómetro y brújula sólo funcionan en dispositivos (iOS/Android); no funciona en el reproductor de escritorio.
- Para la demo del `.fla`: abrirlo en Flash Professional con el `.swc` en la ruta de bibliotecas, y publicar como AIR para iOS.

Este software se suministra sin garantía de ningún tipo, y no se asume ninguna responsabilidad por errores o daños que puedan producirse a partir de su uso.

Adicionalmente, no está permitido el uso del contenido de este proyecto (código, documentación o assets) para entrenar sistemas de inteligencia artificial o de aprendizaje automático sin el permiso explícito del autor. Licenciado bajo [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) — ver [`LICENSE`](LICENSE).
