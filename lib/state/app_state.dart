import 'package:falaai_core/falaai_core.dart';
import 'package:flutter/foundation.dart';

import '../account/pin.dart';
import '../chat/message.dart';

export '../account/pin.dart' show PinStatus;
export '../chat/message.dart';

/// Estado do falaai-core no aparelho.
enum CoreStatus {
  /// Abrindo o banco local cifrado.
  starting,

  /// Banco aberto; o core aceita chamadas.
  ready,

  /// O banco não abriu (chave ausente ou errada, biblioteca nativa ausente).
  failed,
}

/// Se este aparelho já tem conta.
enum AccountStatus {
  /// Lendo a conta guardada.
  loading,

  /// Sem registro: o app abre no onboarding.
  unregistered,

  /// Registrado e com o bundle de chaves publicado.
  registered,
}

/// Conta do aparelho, como a UI precisa. As credenciais ficam fora: o token não entra no estado.
@immutable
class AccountState {
  const AccountState({
    this.status = AccountStatus.loading,
    this.profileName,
    this.pin = PinStatus.notOffered,
    this.pinReminderDue = false,
  });

  final AccountStatus status;
  final String? profileName;
  final PinStatus pin;

  /// O PIN foi adiado e já passou a hora de lembrar.
  final bool pinReminderDue;

  AccountState copyWith({
    AccountStatus? status,
    String? profileName,
    PinStatus? pin,
    bool? pinReminderDue,
  }) => AccountState(
    status: status ?? this.status,
    profileName: profileName ?? this.profileName,
    pin: pin ?? this.pin,
    pinReminderDue: pinReminderDue ?? this.pinReminderDue,
  );

  @override
  bool operator ==(Object other) =>
      other is AccountState &&
      other.status == status &&
      other.profileName == profileName &&
      other.pin == pin &&
      other.pinReminderDue == pinReminderDue;

  @override
  int get hashCode => Object.hash(status, profileName, pin, pinReminderDue);
}

/// Por que o último passo do onboarding não deu certo, para a tela explicar.
enum OnboardingError {
  /// Não é um celular do Brasil, ou o servidor recusou o número.
  invalidPhone,

  /// Código do SMS errado ou vencido.
  invalidCode,

  /// Muitas tentativas.
  rateLimited,

  /// Sem conexão com o servidor.
  network,

  /// O servidor não atende agora (registro desligado, PIN ainda indisponível).
  unavailable,

  /// Falha no aparelho ou resposta inesperada.
  failed,
}

/// Passos em andamento do onboarding. Some quando o registro termina.
@immutable
class OnboardingState {
  const OnboardingState({this.phone, this.error});

  /// Celular em E.164 à espera do código do SMS.
  final String? phone;

  final OnboardingError? error;

  /// [phone] e [error] trocados; os dois aceitam `null` (sem número, sem erro).
  OnboardingState copyWith({
    String? Function()? phone,
    OnboardingError? Function()? error,
  }) => OnboardingState(
    phone: phone != null ? phone() : this.phone,
    error: error != null ? error() : this.error,
  );

  @override
  bool operator ==(Object other) =>
      other is OnboardingState && other.phone == phone && other.error == error;

  @override
  int get hashCode => Object.hash(phone, error);
}

/// A conversa aberta na tela de chat: só a janela de mensagens carregada, da mais antiga à
/// mais nova. Rolar para cima traz mais uma página; a conversa inteira nunca fica em memória.
@immutable
class OpenConversation {
  const OpenConversation({
    required this.peer,
    this.messages = const [],
    this.hasOlder = false,
  });

  final DeviceAddress peer;
  final List<Message> messages;

  /// Há mensagens antes da primeira da janela.
  final bool hasOlder;

  String get id => peer.aci;

  OpenConversation copyWith({List<Message>? messages, bool? hasOlder}) =>
      OpenConversation(
        peer: peer,
        messages: messages ?? this.messages,
        hasOlder: hasOlder ?? this.hasOlder,
      );

  @override
  bool operator ==(Object other) =>
      other is OpenConversation &&
      other.peer == peer &&
      listEquals(other.messages, messages) &&
      other.hasOlder == hasOlder;

  @override
  int get hashCode => Object.hash(peer, Object.hashAll(messages), hasOlder);
}

/// Conversas e a tela de chat.
@immutable
class ChatState {
  const ChatState({
    this.conversations = const [],
    this.open,
    this.typing = const {},
  });

  /// Lista de conversas, da mais recente à mais antiga.
  final List<ConversationSummary> conversations;

  /// A conversa na tela de chat; `null` fora dela.
  final OpenConversation? open;

  /// Conversas (pelo id) cujo contato está digitando agora.
  final Set<String> typing;

  /// [open] aceita `null` (nenhuma conversa aberta).
  ChatState copyWith({
    List<ConversationSummary>? conversations,
    OpenConversation? Function()? open,
    Set<String>? typing,
  }) => ChatState(
    conversations: conversations ?? this.conversations,
    open: open != null ? open() : this.open,
    typing: typing ?? this.typing,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatState &&
      listEquals(other.conversations, conversations) &&
      other.open == open &&
      setEquals(other.typing, typing);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(conversations), open, Object.hashAll(typing));
}

/// Estado único do app (Async Redux). Imutável: os reducers devolvem cópias.
@immutable
class AppState {
  const AppState({
    this.core = CoreStatus.starting,
    this.account = const AccountState(),
    this.onboarding = const OnboardingState(),
    this.chat = const ChatState(),
  });

  final CoreStatus core;
  final AccountState account;
  final OnboardingState onboarding;
  final ChatState chat;

  AppState copyWith({
    CoreStatus? core,
    AccountState? account,
    OnboardingState? onboarding,
    ChatState? chat,
  }) => AppState(
    core: core ?? this.core,
    account: account ?? this.account,
    onboarding: onboarding ?? this.onboarding,
    chat: chat ?? this.chat,
  );

  @override
  bool operator ==(Object other) =>
      other is AppState &&
      other.core == core &&
      other.account == account &&
      other.onboarding == onboarding &&
      other.chat == chat;

  @override
  int get hashCode => Object.hash(core, account, onboarding, chat);
}
