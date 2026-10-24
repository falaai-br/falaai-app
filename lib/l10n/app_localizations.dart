import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('pt')];

  /// Nome do app, na barra do topo e no seletor de apps.
  ///
  /// In pt, this message translates to:
  /// **'FalaAí'**
  String get appTitle;

  /// Enquanto o banco local cifrado é aberto, logo ao abrir o app.
  ///
  /// In pt, this message translates to:
  /// **'Preparando suas conversas…'**
  String get coreStarting;

  /// O banco local cifrado não abriu.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível abrir suas conversas neste aparelho.'**
  String get coreFailed;

  /// Lista de conversas vazia.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma conversa ainda.'**
  String get homeEmpty;

  /// Rodapé da primeira tela do cadastro. Fala de privacidade sem jargão de criptografia.
  ///
  /// In pt, this message translates to:
  /// **'Só você e quem recebe podem ler suas mensagens.'**
  String get onboardingPrivacy;

  /// Título da tela do número, primeira do cadastro.
  ///
  /// In pt, this message translates to:
  /// **'Qual é o seu celular?'**
  String get phoneTitle;

  /// Explicação da tela do número.
  ///
  /// In pt, this message translates to:
  /// **'Vamos enviar um código por SMS para confirmar que o número é seu.'**
  String get phoneMessage;

  /// Rótulo do campo do número.
  ///
  /// In pt, this message translates to:
  /// **'Celular com DDD'**
  String get phoneLabel;

  /// Exemplo no campo do número.
  ///
  /// In pt, this message translates to:
  /// **'(11) 91234-5678'**
  String get phoneHint;

  /// O número digitado não é um celular brasileiro, ou o servidor o recusou.
  ///
  /// In pt, this message translates to:
  /// **'Digite um celular do Brasil com DDD.'**
  String get phoneInvalid;

  /// Botão que avança no cadastro.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get continueButton;

  /// Título da tela do código do SMS.
  ///
  /// In pt, this message translates to:
  /// **'Digite o código'**
  String get codeTitle;

  /// Explicação da tela do código.
  ///
  /// In pt, this message translates to:
  /// **'Enviamos um código por SMS para {phone}.'**
  String codeMessage(String phone);

  /// Rótulo do campo do código do SMS.
  ///
  /// In pt, this message translates to:
  /// **'Código de {length} dígitos'**
  String codeLabel(int length);

  /// Botão que confere o código e registra o aparelho.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get codeConfirm;

  /// Volta para a tela do número.
  ///
  /// In pt, this message translates to:
  /// **'Mudar número'**
  String get codeEditPhone;

  /// O servidor recusou o código.
  ///
  /// In pt, this message translates to:
  /// **'Código incorreto. Confira o SMS e tente de novo.'**
  String get codeInvalid;

  /// O servidor limitou as tentativas.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas. Espere um pouco e tente de novo.'**
  String get errorRateLimited;

  /// Falha de rede no cadastro.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com o servidor. Confira sua internet e tente de novo.'**
  String get errorNetwork;

  /// O servidor não aceita registros no momento.
  ///
  /// In pt, this message translates to:
  /// **'O cadastro está indisponível agora. Tente mais tarde.'**
  String get errorUnavailable;

  /// Falha local ou resposta inesperada do servidor.
  ///
  /// In pt, this message translates to:
  /// **'Algo deu errado neste aparelho. Tente de novo.'**
  String get errorFailed;

  /// Título da tela do nome do perfil.
  ///
  /// In pt, this message translates to:
  /// **'Como você quer ser chamado?'**
  String get nameTitle;

  /// Explicação da tela do nome.
  ///
  /// In pt, this message translates to:
  /// **'Seu nome aparece para as pessoas com quem você conversa.'**
  String get nameMessage;

  /// Rótulo do campo do nome.
  ///
  /// In pt, this message translates to:
  /// **'Seu nome'**
  String get nameLabel;

  /// Título da tela do PIN de registro.
  ///
  /// In pt, this message translates to:
  /// **'Crie um PIN'**
  String get pinTitle;

  /// Explicação da tela do PIN.
  ///
  /// In pt, this message translates to:
  /// **'Com o PIN, ninguém registra sua conta em outro aparelho, mesmo que receba o código do SMS.'**
  String get pinMessage;

  /// Rótulo do campo do PIN.
  ///
  /// In pt, this message translates to:
  /// **'PIN (pelo menos {length} números)'**
  String pinLabel(int length);

  /// Rótulo do campo de confirmação do PIN.
  ///
  /// In pt, this message translates to:
  /// **'Repita o PIN'**
  String get pinConfirmLabel;

  /// A confirmação não bate com o PIN.
  ///
  /// In pt, this message translates to:
  /// **'Os PINs não são iguais.'**
  String get pinMismatch;

  /// Botão que cria o PIN.
  ///
  /// In pt, this message translates to:
  /// **'Criar PIN'**
  String get pinCreate;

  /// Adia a criação do PIN.
  ///
  /// In pt, this message translates to:
  /// **'Agora não'**
  String get pinLater;

  /// Abaixo dos botões da tela do PIN.
  ///
  /// In pt, this message translates to:
  /// **'Se preferir, crie depois. Vamos lembrar você.'**
  String get pinLaterHint;

  /// O servidor não aceitou criar o PIN no momento.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível criar o PIN agora. Tente mais tarde.'**
  String get pinUnavailable;

  /// Lembrete na lista de conversas depois que o PIN foi adiado.
  ///
  /// In pt, this message translates to:
  /// **'Crie um PIN para proteger sua conta.'**
  String get pinReminder;

  /// Leitor de tela: botão esperando a resposta do servidor.
  ///
  /// In pt, this message translates to:
  /// **'Aguarde…'**
  String get waiting;

  /// Botão na lista de conversas e título do diálogo.
  ///
  /// In pt, this message translates to:
  /// **'Nova conversa'**
  String get chatNew;

  /// Explicação no diálogo de nova conversa.
  ///
  /// In pt, this message translates to:
  /// **'Digite o ID da conta da pessoa. Convite por link, QR e nome de usuário vêm em breve.'**
  String get chatNewMessage;

  /// Campo do diálogo de nova conversa.
  ///
  /// In pt, this message translates to:
  /// **'ID da conta'**
  String get chatNewLabel;

  /// O texto digitado não é um UUID.
  ///
  /// In pt, this message translates to:
  /// **'Isso não é um ID de conta.'**
  String get chatNewInvalid;

  /// Confirma o diálogo de nova conversa.
  ///
  /// In pt, this message translates to:
  /// **'Conversar'**
  String get chatNewOpen;

  /// Fecha um diálogo sem fazer nada.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// Nome de um contato sem perfil ainda; {id} é o começo do ID da conta.
  ///
  /// In pt, this message translates to:
  /// **'Contato {id}'**
  String chatContact(String id);

  /// Quem mandou, nas mensagens enviadas (leitor de tela).
  ///
  /// In pt, this message translates to:
  /// **'Você'**
  String get chatYou;

  /// Prévia na lista quando a última mensagem é sua.
  ///
  /// In pt, this message translates to:
  /// **'Você: {text}'**
  String chatPreviewOutgoing(String text);

  /// Na lista de conversas, no lugar da prévia, enquanto o contato digita.
  ///
  /// In pt, this message translates to:
  /// **'digitando…'**
  String get chatTyping;

  /// Indicador na tela de chat.
  ///
  /// In pt, this message translates to:
  /// **'{name} está digitando…'**
  String chatTypingName(String name);

  /// Leitor de tela para o contador de não lidas.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{{count} mensagem não lida} other{{count} mensagens não lidas}}'**
  String chatUnread(int count);

  /// Tela de chat sem mensagens.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma mensagem ainda. Só você e quem recebe podem ler.'**
  String get chatEmpty;

  /// Ao rolar até o início da janela de mensagens.
  ///
  /// In pt, this message translates to:
  /// **'Carregando mensagens anteriores…'**
  String get chatLoadingOlder;

  /// Campo de texto da tela de chat.
  ///
  /// In pt, this message translates to:
  /// **'Mensagem'**
  String get chatComposerHint;

  /// Botão de enviar.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get chatSend;

  /// Recibo: na fila, ainda não chegou ao servidor.
  ///
  /// In pt, this message translates to:
  /// **'Enviando'**
  String get chatStatusPending;

  /// Recibo: o servidor gravou na fila do destinatário.
  ///
  /// In pt, this message translates to:
  /// **'Enviada'**
  String get chatStatusSent;

  /// Recibo: o aparelho do contato recebeu.
  ///
  /// In pt, this message translates to:
  /// **'Entregue'**
  String get chatStatusDelivered;

  /// Recibo: o contato leu.
  ///
  /// In pt, this message translates to:
  /// **'Lida'**
  String get chatStatusRead;

  /// Recibo: o envio falhou de vez.
  ///
  /// In pt, this message translates to:
  /// **'Não foi enviada'**
  String get chatStatusFailed;

  /// Falha de envio: sem sessão com o contato.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há uma conversa segura com esta pessoa.'**
  String get chatFailedNoSession;

  /// Falha de envio: identidade do contato não confiável.
  ///
  /// In pt, this message translates to:
  /// **'O código de segurança mudou. Confira antes de enviar.'**
  String get chatFailedIdentity;

  /// Falha de envio: destinatário inexistente.
  ///
  /// In pt, this message translates to:
  /// **'Esta conta não existe.'**
  String get chatFailedUnknownAccount;

  /// Falha de envio: este aparelho não tem conta.
  ///
  /// In pt, this message translates to:
  /// **'Termine o cadastro para enviar mensagens.'**
  String get chatFailedNoAccount;

  /// Falha de envio por outro motivo.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível enviar.'**
  String get chatFailedOther;

  /// Aviso acima da mensagem em que a chave do contato mudou.
  ///
  /// In pt, this message translates to:
  /// **'O código de segurança desta conversa mudou.'**
  String get chatIdentityChanged;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
