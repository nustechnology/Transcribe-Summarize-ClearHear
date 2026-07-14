# flutter_llama constructs these from JNI (nativeGenerate / nativeGetModelInfo).
# R8 cannot see those call sites and strips the constructors in release builds,
# which crashes with:
#   NoSuchMethodError: FlutterLlamaPlugin$GenerationResult.<init>(String, int)
-keep class net.nativemind.flutter_llama.FlutterLlamaPlugin {
  *;
}
-keep class net.nativemind.flutter_llama.FlutterLlamaPlugin$GenerationResult {
  <init>(java.lang.String, int);
  *;
}
-keep class net.nativemind.flutter_llama.FlutterLlamaPlugin$ModelInfo {
  <init>(long, int, int);
  *;
}
