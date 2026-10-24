// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'FalaAí';

  @override
  String get coreStarting => 'Preparando suas conversas…';

  @override
  String get coreFailed =>
      'Não foi possível abrir suas conversas neste aparelho.';

  @override
  String get homeEmpty => 'Nenhuma conversa ainda.';

  @override
  String get onboardingPrivacy =>
      'Só você e quem recebe podem ler suas mensagens.';

  @override
  String get phoneTitle => 'Qual é o seu celular?';

  @override
  String get phoneMessage =>
      'Vamos enviar um código por SMS para confirmar que o número é seu.';

  @override
  String get phoneLabel => 'Celular com DDD';

  @override
  String get phoneHint => '(11) 91234-5678';

  @override
  String get phoneInvalid => 'Digite um celular do Brasil com DDD.';

  @override
  String get continueButton => 'Continuar';

  @override
  String get codeTitle => 'Digite o código';

  @override
  String codeMessage(String phone) {
    return 'Enviamos um código por SMS para $phone.';
  }

  @override
  String codeLabel(int length) {
    return 'Código de $length dígitos';
  }

  @override
  String get codeConfirm => 'Confirmar';

  @override
  String get codeEditPhone => 'Mudar número';

  @override
  String get codeInvalid => 'Código incorreto. Confira o SMS e tente de novo.';

  @override
  String get errorRateLimited =>
      'Muitas tentativas. Espere um pouco e tente de novo.';

  @override
  String get errorNetwork =>
      'Sem conexão com o servidor. Confira sua internet e tente de novo.';

  @override
  String get errorUnavailable =>
      'O cadastro está indisponível agora. Tente mais tarde.';

  @override
  String get errorFailed => 'Algo deu errado neste aparelho. Tente de novo.';

  @override
  String get nameTitle => 'Como você quer ser chamado?';

  @override
  String get nameMessage =>
      'Seu nome aparece para as pessoas com quem você conversa.';

  @override
  String get nameLabel => 'Seu nome';

  @override
  String get pinTitle => 'Crie um PIN';

  @override
  String get pinMessage =>
      'Com o PIN, ninguém registra sua conta em outro aparelho, mesmo que receba o código do SMS.';

  @override
  String pinLabel(int length) {
    return 'PIN (pelo menos $length números)';
  }

  @override
  String get pinConfirmLabel => 'Repita o PIN';

  @override
  String get pinMismatch => 'Os PINs não são iguais.';

  @override
  String get pinCreate => 'Criar PIN';

  @override
  String get pinLater => 'Agora não';

  @override
  String get pinLaterHint => 'Se preferir, crie depois. Vamos lembrar você.';

  @override
  String get pinUnavailable =>
      'Não foi possível criar o PIN agora. Tente mais tarde.';

  @override
  String get pinReminder => 'Crie um PIN para proteger sua conta.';

  @override
  String get waiting => 'Aguarde…';

  @override
  String get chatNew => 'Nova conversa';

  @override
  String get chatNewMessage =>
      'Digite o ID da conta da pessoa. Convite por link, QR e nome de usuário vêm em breve.';

  @override
  String get chatNewLabel => 'ID da conta';

  @override
  String get chatNewInvalid => 'Isso não é um ID de conta.';

  @override
  String get chatNewOpen => 'Conversar';

  @override
  String get cancel => 'Cancelar';

  @override
  String chatContact(String id) {
    return 'Contato $id';
  }

  @override
  String get chatYou => 'Você';

  @override
  String chatPreviewOutgoing(String text) {
    return 'Você: $text';
  }

  @override
  String get chatTyping => 'digitando…';

  @override
  String chatTypingName(String name) {
    return '$name está digitando…';
  }

  @override
  String chatUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens não lidas',
      one: '$count mensagem não lida',
    );
    return '$_temp0';
  }

  @override
  String get chatEmpty =>
      'Nenhuma mensagem ainda. Só você e quem recebe podem ler.';

  @override
  String get chatLoadingOlder => 'Carregando mensagens anteriores…';

  @override
  String get chatComposerHint => 'Mensagem';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatStatusPending => 'Enviando';

  @override
  String get chatStatusSent => 'Enviada';

  @override
  String get chatStatusDelivered => 'Entregue';

  @override
  String get chatStatusRead => 'Lida';

  @override
  String get chatStatusFailed => 'Não foi enviada';

  @override
  String get chatFailedNoSession =>
      'Ainda não há uma conversa segura com esta pessoa.';

  @override
  String get chatFailedIdentity =>
      'O código de segurança mudou. Confira antes de enviar.';

  @override
  String get chatFailedUnknownAccount => 'Esta conta não existe.';

  @override
  String get chatFailedNoAccount => 'Termine o cadastro para enviar mensagens.';

  @override
  String get chatFailedOther => 'Não foi possível enviar.';

  @override
  String get chatIdentityChanged =>
      'O código de segurança desta conversa mudou.';
}
