# Audit jank Flutter Web — Kiki Commerce

> **Statut : inventaire de référence, pas une todo vivante.** Instantané des
> hotspots au moment de l'audit — certains ont pu être corrigés depuis (vérifier
> le code avant d'agir). Pour la règle anti-jank permanente, voir `CLAUDE.md`
> (« Rendering perf: avoid introducing jank ») ; pour le protocole de mesure,
> `docs/dev/storefront_performance_profiling.md`. Pour l'investigation jank
> Android (S22 Ultra) qui a clos une partie de cet audit, voir la section
> « Mise à jour 2026-07-01 » en bas de page.

## Synthèse
L’audit identifie un hotspot prioritaire confirmé : `MobilePdpPurchaseSurface`, qui mesure la position de l’ancre d’achat en post-frame pendant le scroll mobile.

Deux autres zones sont à surveiller sérieusement :
- `StorefrontStickySidebar`, qui met à jour un `Positioned(top)` pendant le scroll ;
- `NarrativePdpSection`, qui mesure plusieurs `GlobalKey` pendant le scroll.

`MixedProductGridSection` n’est pas un jank de scroll direct, mais un risque de long frame initial si la grille CMS contient beaucoup de produits, car elle n’est pas lazy.

`ScrollRevealText` a déjà été fortement optimisé par de récents commits. Il reste une lecture géométrique par frame de scroll, mais les rebuilds inutiles sont évités. À classer en P2 sauf preuve DevTools.

*Note technique : Dans Flutter Web, `findRenderObject()` et `localToGlobal()` ne mesurent pas directement le DOM, ce sont des lectures synchrones de l’arbre de rendu Flutter. Ces lectures de géométrie restent potentiellement coûteuses si elles surviennent à chaque tick de scroll.*

## Hotspots et Priorités révisées

| Priorité | Fichier | Widget | Pattern | Risque | Recommandation |
|---|---|---|---|---|---|
| **P0/P1** | `product_detail_mobile_purchase_surface.dart` | `MobilePdpPurchaseSurface` | `NotificationListener` schedule une mesure post-frame pendant le scroll ; grâce à `_measureScheduled`, cela est coalescé à une mesure max par frame, mais `localToGlobal` reste exécuté très fréquemment pendant un scroll continu. | Fort (Jank visible sur la PDP Mobile). L'appel répétitif relit l'arbre, bien qu'il y ait des garde-fous (seuil de 0.5px et limite d'une frame). | Réduire ou mettre en cache le recours à `localToGlobal` pendant le scroll (ex: calculer la position à partir du scroll offset ou limiter la fréquence près de la zone de transition). |
| **P1** | `storefront_layout.dart` | `StorefrontStickySidebar` | `addListener` de `ScrollPosition` modifie `_translateY` et appelle `setState` sur un `Positioned(top: _translateY)`. | Moyen. Même avec un seuil de 0.5px pour l'update, le widget force une passe layout au lieu d'une composition visuelle. | Remplacer `Positioned(top: ...)` par `Transform.translate` et isoler la translation dans un sous-arbre minimal, idéalement via `ValueListenableBuilder` + `RepaintBoundary`, pour éviter de relayout le sticky panel complet. |
| **P1** | `mixed_product_grid_section.dart` | `_ResponsiveMixedGrid` | Utilisation d'un `LayoutBuilder` qui mappe les enfants dans une `Column` contenant des `Row`. Grille non "lazy". | Fort **uniquement** si le nombre d'articles grandit. Acceptable pour un MVP (limit ~ 8-16). | Ne pas refactorer de suite. Prévoir `SliverGrid` si le mixed grid devient une PLP longue. |
| **P1/P2** | `product_detail_narrative_section.dart` | `NarrativePdpSection` | `_syncCurrentIndexToVisibleImage` boucle sur les `GlobalKey` de toutes les images pour invoquer `localToGlobal` à chaque scroll. | Moyen à Fort (dépend du nombre d'images : négligeable pour 3-5, risqué pour 15-30). | Limiter les mesures aux index proches (±1) plutôt que d'itérer sur toute la liste à chaque frame. |
| **P2** | `scroll_reveal_text.dart` | `ScrollRevealText` | L'`addListener` du scroll appelle un post-frame tick pour lire la position via `localToGlobal`. | Faible (le rebuild est protégé par `activeCount`). | Ne plus toucher sans trace DevTools claire prouvant un jank. |
| **P2** | `kiki_image.dart` | `KikiImage` | Enveloppe la logique d'image dans un `LayoutBuilder` si aucune dimension explicite n'est donnée. | Faible — **vérifié empiriquement le 2026-07-01 : ne se déclenche sur aucun des 11 usages actuels de la landing/PLP/PDP** (voir mise à jour en bas de page). Durci par sécurité quand même. | Fallback déjà durci (`MediaQuery.sizeOf` au lieu de `double.infinity`, commit `37835c9`). |

## Analyse détaillée par zone

### Landing & PLP
- **PLP CMS (`MixedProductGridSection`)** : Actuellement codé sans virtualisation. Cela fonctionne bien pour un très petit nombre mais dégradera les performances (long frame initial) sur de grandes catégories.
- **`CmsSectionReveal`** : Superbe gestion de l'animation ! L'approche `if (t >= 1.0) return child!;` annule la pénalité GPU/Compositing après l'apparition.
- **`ProductCard`** : Propre. Gère intelligemment la précharge `precacheImage` et l'affichage des caches d'images. 

### Navigation shell
- **`PremiumShellNavbar`** : Excellent. L'optimisation agit comme un seuil parfait et bloque les re-rendus sur l'intégralité du trajet du scroll.

### PDP (Product Detail Page)
- **`MobilePdpPurchaseSurface`** : Écouter l'intégralité du flux `ScrollNotification` et lancer un check coalescé mais fréquent avec `localToGlobal` ralentit la frame. C'est le **Quick Win prioritaire**.
- **`NarrativePdpSection`** : L'effet d'ancre lit continuellement les positions de toutes les images. Risque modéré selon le volume.
- **`DesktopImageStack` / `ImageCarousel`** : Bien fait. Ils encadrent les images critiques avec `RepaintBoundary` et le carrousel textuel emploie sagement le `PageView`. 

## Ordre de correction recommandé

1. **`MobilePdpPurchaseSurface`** : réduire les mesures `localToGlobal()` pendant le scroll. C’est le vrai quick win prioritaire.
2. **`StorefrontStickySidebar`** : passer de `Positioned(top)` à `Transform.translate` et isoler la mise à jour via un `ValueNotifier`.
3. **`NarrativePdpSection`** : limiter les mesures aux index proches, si DevTools confirme.
4. **`MixedProductGridSection`** : ne pas refactorer tant que les `limit` restent faibles ; prévoir une version lazy si tu veux en faire une vraie PLP longue.
5. **`ScrollRevealText`** : ne plus toucher maintenant, sauf trace DevTools claire.

## Plan de validation DevTools

**Protocole manuel pour confirmer l'impact des mesures de l'arbre au scroll et tester les correctifs :**
1. Builder pour le profilage local via `flutter run -d chrome --profile --wasm`
   (prod utilise skwasm ; profiler avec `--wasm` pour matcher le renderer réel).
2. Ouvrir les **Flutter DevTools**, cibler l'onglet **Performance**.
3. **Cas de la PDP Mobile** :
   - Accéder à une Page Produit affichant le mode `MobilePdpPurchaseSurface`.
   - Activer le mode *Enhance Tracing* pour surveiller la source des temps CPU.
   - Faire de grands scrolls de balayage sur le contenu.
   - *Alerte Jank* : Si des barres rouges (> 16ms) apparaissent, vérifier si elles corrèlent avec les appels post-frame à `_measureAnchor` et les mesures `localToGlobal()`.
4. **Cas de la Grille PLP** :
   - Accéder à une catégorie CMS avec de nombreux produits en utilisant le module MixedGrid.
   - Recharger la page avec l'enregistrement Performance actif.
   - *Alerte Jank* : Temps anormalement lourd passé sur la frame initiale, démontrant potentiellement que la liste "non lazy" gèle le thread lors du montage.

## Mise à jour 2026-07-01 — clôture partielle (investigation Android S22 Ultra)

Investigation menée sur device physique (Samsung Galaxy S22 Ultra, Android 16)
sur la landing `/en` et, en comparaison, les PLP `usui-takumi` /
`summer-essentials` et la PDP `summer-essentials/gapy-style`. Deux bugs réels
corrigés ; le jank résiduel restant sur la landing n'a pas de cause Flutter
actionnable identifiée.

### Corrections appliquées

- **`37835c9`** — la landing décodait deux fois certaines images de
  hero/banner : une fois en pleine résolution native via
  `precacheImage(CachedNetworkImageProvider(url), context)` (aucune contrainte
  de taille), puis une seconde fois à la bonne taille par le widget réel
  (`KikiImage`), la clé de cache ne correspondant pas entre les deux appels.
  Le premier décodage, gâché, coûtait 300ms+ par image sur ce device. Fix :
  les deux appels `precacheImage` de `storefront_landing_page.dart`
  utilisent maintenant un `ResizeImage` borné à la largeur physique de
  l'écran. `KikiImage` a aussi été durci par sécurité (voir note dans le
  tableau des hotspots ci-dessus). **Effet mesuré** : pire frame raster de la
  landing 101.7ms → 41ms ; frames ayant raté leur budget raster 20/181 (11%)
  → 7/278 (2.5%) ; les événements `DecompressTexture` de plus de 100ms ont
  disparu de la trace. PLP/PDP inchangées (déjà à 0 frame ratée avant et
  après).
- **`5ada04f`** — `_AdaptiveBottomNavState._sample()` (nav flottante,
  adaptation clair/sombre selon le fond) lisait
  `RenderObject.debugNeedsPaint`, un getter dont le champ n'est assigné que
  dans un bloc `assert()` — donc jamais initialisé en profil/release
  (asserts supprimés), d'où un `LateInitializationError` systématique à
  chaque fin de scroll. Reproduit aussi bien en profil Android qu'en release
  web. Fix : suppression du pré-check, la logique de retry passe par le
  `catch` déjà existant. Comportement visuel inchangé, aucune nouvelle
  surface d'API.

### Jank résiduel landing : pas de cause Flutter actionnable identifiée

Après les deux fixs ci-dessus, la landing garde occasionnellement des frames
raster à 35-50ms (contre 0 frame ratée sur PLP/PDP dans les mêmes
conditions). Investigation par isolation empirique — chaque piste a été
testée avec une modification temporaire non commitée, reprofilée avec le
même harness, puis annulée :

| Piste écartée | Test effectué | Résultat |
|---|---|---|
| `CmsSectionReveal` (fade/slide d'entrée des sections CMS) | Désactivé entièrement | Nombre de `saveLayer` quasi inchangé (1586→1591) ; pics toujours présents (38ms) |
| `BackdropFilter` de la bottom nav (`floating_bottom_nav.dart`, blur sigma 30) | Retiré | Nombre de `saveLayer` en forte baisse (1586→1079, confirme un coût réel par frame) mais la pire frame reste identique (52.96ms) |
| Tailles de thumbnails CMS / décodage `KikiImage` | Audité précisément (URL, taille affichée, taille décodée, dpr) sur les 3 images réellement chargées sur la landing et les 4 de la PLP | **Décodage exact à `taille affichée × devicePixelRatio` sur toutes les images, landing et PLP** — aucun surdimensionnement mesuré. Aucune cible valide pour un patch de réduction |
| Vidéo hero (`LandingHeroVideo`, autoplay sans pause hors viewport) | Désactivée par code, puis vérifiée : elle n'existe même plus dans le contenu CMS live actuel (section `hero_campaign` absente de `homepage_nike` et de toutes les pages sœurs) | Chiffres identiques avec ou sans (swing mémoire GPU 113MB dans les deux cas) — l'amélioration apparente d'un premier test n'était que du bruit de mesure |

**Cause probable** : les pires frames sont des `Canvas::saveLayer` dont le
Begin→End est vide (rien ne s'exécute dedans) pendant que le budget mémoire
GPU (`AllocatorVK`, moteur Impeller/Vulkan) oscille de ~125MB, avec des
`ReclaimResources`/`DestroyImage` de 20-45ms dans la même fenêtre. Sur PLP/PDP
(propres), ce swing est de 0-4MB. Le nombre brut de `saveLayer` n'est **pas**
corrélé au jank (PLP/PDP en émettent plus que la landing : 3425 et 2125
contre 1586, sans aucun impact). Ça ressemble à une caractéristique de
l'allocateur mémoire GPU Impeller/Vulkan propre à ce device (Samsung Exynos),
possiblement liée à l'avertissement `userfaultfd: MOVE ioctl seems
unsupported: Connection timed out` qui apparaît dans **tous** les runs de
cette investigation, quelle que soit la variante testée — donc a priori pas
quelque chose qu'un changement de widget applicatif peut résoudre.

**Point de méthode important** : le backend PocketBase de dev utilisé ici est
**live et mutable** — son contenu CMS a changé en cours d'investigation (la
vidéo hero a disparu de `homepage_nike` entre deux passes de tests, sans
qu'aucun code n'ait changé). Avant d'interpréter une trace ou de reprendre
cette investigation, revérifier l'état réel du contenu CMS via l'API
PocketBase (lecture publique, pas d'auth nécessaire) plutôt que de se fier à
une observation précédente :
```
GET https://kiki-commerce.pockethost.io/api/collections/page_sections/records?filter=(page='<pageId>')
```

### Méthodologie de mesure fiable (réutilisable)

1. `flutter drive --target=test_driver/app.dart --driver=test_driver/scroll_perf_test.dart --profile -d <device-id> --route=<route>` sur un **device physique** (jamais un simulateur/émulateur pour un verdict de jank) — voir `test_driver/scroll_perf_test.dart`, conservé dans le repo.
2. Le scroll est un vrai geste tactile envoyé via `adb shell input swipe`, pas un geste synthétique du driver — pour que la timeline reflète un scroll réel.
3. Toujours comparer la route suspecte à une route propre dans les mêmes conditions (ici : landing vs PLP `usui-takumi`/`summer-essentials` vs PDP `gapy-style`) — un chiffre absolu (« 40ms de raster ») ne veut rien dire seul ; c'est l'écart à une route propre qui qualifie un vrai problème.
4. Dans le JSON de timeline (`build/perf/*.timeline.json`, non commité), chercher spécifiquement :
   - `DecompressTexture` — décodage d'image sur les threads `FlutterConcurrentMessageLoopWorker` ; long (>100ms) = image décodée à une résolution trop grande.
   - `Canvas::saveLayer` — coût de compositing (opacité, blur, clip complexe) ; un Begin→End **vide** de plusieurs dizaines de ms indique un blocage moteur, pas un rendu coûteux.
   - `AllocatorVK` (`MemoryBudgetUsageMB`) — budget mémoire GPU Impeller/Vulkan ; un swing important corrélé aux pires frames pointe vers une pression mémoire GPU plutôt qu'un widget spécifique.
   - `ReclaimResources` / `DestroyImage` — libération de ressources GPU ; coûteux et synchrone quand ils apparaissent dans la fenêtre d'une frame lente.
5. Ne jamais conclure à partir du seul nombre d'événements `saveLayer` : sur ce projet, la route la plus propre (PDP) en émet *plus* que la route la plus janky (landing) — c'est le swing mémoire et la durée des events vides qui qualifient un vrai problème, pas le volume.
6. Isoler une hypothèse par une modification **temporaire et non commitée** (un seul point de bascule à la fois), reprofiler avec le même harness, puis annuler avant de tester la suivante — ne jamais empiler plusieurs hypothèses dans un même run.
