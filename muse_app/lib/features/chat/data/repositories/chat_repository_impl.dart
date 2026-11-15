import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';
import '../models/chat_message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this.remote);
  final ChatRemoteDataSource remote;
  @override
  Stream<String> streamReply(
    ServerConnection connection,
    List<ChatMessage> messages,
  ) => remote.streamReply(
    connection,
    messages.map(ChatMessageModel.toJson).toList(),
  );
}
