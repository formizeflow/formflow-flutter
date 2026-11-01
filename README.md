# formizeflow (Flutter)

[![CI](https://github.com/formizeflow/formflow-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/formizeflow/formflow-flutter/actions/workflows/ci.yml)

Show FormFlow forms in Flutter on `webview_flutter`. The page talks to the app through a `JavaScriptChannel` named `FormFlowFlutter`. No credentials in the app.

```yaml
dependencies:
  formizeflow: ^0.1.0   # or: formizeflow: { git: https://github.com/formizeflow/formflow-flutter }
```

## Onboarding on first launch

```dart
FormFlowForm(
  config: FormFlowConfig(baseUrl: 'https://forms.example.com', slug: 'app-onboarding', uid: user.id, hidden: {'app_version': '3.2.0'}, showClose: true),
  onComplete: (c) { prefs.setBool('onboarded', true); Navigator.of(context).pop(); },
  onClose: () => Navigator.of(context).pop(),
  onTimeout: () => Navigator.of(context).pop(),   // never block the app on a slow network
)
```

Events: `FormFlowReady(formId, versionId, experimentId, variantId, locale)`, `FormFlowView`, `FormFlowStart`, `FormFlowStep(index, fieldId, total)`, `FormFlowAnswer(fieldId, type, value)`, `FormFlowComplete(submissionId, outcome, endingId, durationMs, answers)`, `FormFlowRequestEvent`, `FormFlowProgress`, `FormFlowClose`, `FormFlowError`. Values appear only with `includeAnswers: true` and never for sensitive fields. Navigation stays on the base host; other links open in an in-app browser (`url_launcher`). The user agent ends with `FormFlowFlutter/<version>`.

## Onboarding experiment: decide, preload, fall back

```dart
final client = FormFlowClient(baseUrl: 'https://forms.example.com'); // pass storage: for a cache across launches
client.preload(entry: 'first-launch', uid: user.id, uidSignature: user.formflowSig); // app start

// onboarding step
final base = FormFlowConfig(
  baseUrl: 'https://forms.example.com', slug: '', uid: user.id, uidSignature: user.formflowSig,
  attributes: {'plan': user.plan}, appVersion: '3.2.0', includeAnswers: true,
  posthogSessionId: await Posthog().getSessionId(), posthogDistinctId: await Posthog().getDistinctId(),
  appearance: const FormFlowAppearance(colorScheme: FormFlowColorScheme.system, accent: '#4f46e5'),
);
FormFlowConfig? config;
try { config = (await client.decide(entry: 'first-launch', uid: user.id, uidSignature: user.formflowSig)).config(base); } catch (_) {}
if (config == null) return finishOnboarding();   // holdout, done, or offline with no cache
final controller = FormFlowController();         // controller.restart() starts over
return FormFlowForm(
  config: config, controller: controller,
  onStep: (s) { if (s.fieldId == 'notifications_q') {/* react mid-flow */} },
  onRequest: (r) async => r.action == 'notifications' ? await askNotifications() : 'unsupported',
  onComplete: (c) { save(c.answers); finishOnboarding(); },
  onTimeout: finishOnboarding, onClose: finishOnboarding,
);
```

`uidSignature` is an HMAC of `uid` from your server. In the form, a link like `[Enable notifications](https://example.com/#ff-action=notifications)` triggers `onRequest`. To warm the WebView itself, mount the widget in an `Offstage` ahead of the step.
