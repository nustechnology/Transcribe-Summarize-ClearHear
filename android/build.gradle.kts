import java.util.Locale

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

fun org.gradle.api.Project.pythonExecCommand(script: java.io.File): List<String> {
    val isWindows = System.getProperty("os.name").lowercase(Locale.US).contains("windows")
    val candidates = if (isWindows) {
        listOf(listOf("py", "-3"), listOf("python"), listOf("python3"))
    } else {
        listOf(listOf("python3"), listOf("python"))
    }

    for (baseCmd in candidates) {
        try {
            val probe = providers.exec {
                commandLine(baseCmd + "--version")
                isIgnoreExitValue = true
            }.result.get()
            if (probe.exitValue == 0) {
                return baseCmd + script.absolutePath
            }
        } catch (_: Exception) {
            continue
        }
    }

    throw GradleException(
        "Python 3 is required for setupFlutterLlamaAndroid. " +
            "Install Python 3 and ensure it is on PATH.",
    )
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

val projectRoot = rootProject.layout.projectDirectory.dir("..").asFile
val setupFlutterLlamaPython = projectRoot.resolve("tool/setup_flutter_llama_android.py")
val setupFlutterLlamaScript = projectRoot.resolve("tool/setup_flutter_llama_android.sh")
val patchWhisperKitAndroidScript = projectRoot.resolve("tool/patch_whisper_kit_android.sh")
val pubspecLock = projectRoot.resolve("pubspec.lock")
val setupFlutterLlamaStamp =
    rootProject.layout.buildDirectory.file("setup_flutter_llama_android.stamp")
val patchWhisperKitAndroidStamp =
    rootProject.layout.buildDirectory.file("patch_whisper_kit_android.stamp")

fun pubCacheDirectory(): java.io.File {
    val fromEnv = System.getenv("PUB_CACHE")
    return if (fromEnv != null) java.io.File(fromEnv) else java.io.File(System.getProperty("user.home"), ".pub-cache")
}

fun whisperKitMainCppSources(pubCache: java.io.File): List<java.io.File> {
    val hosted = pubCache.resolve("hosted/pub.dev")
    if (!hosted.isDirectory) {
        return emptyList()
    }
    return hosted.listFiles { file ->
        file.isDirectory && file.name.startsWith("whisper_kit-")
    }?.mapNotNull { packageDir ->
        packageDir.resolve("src/main.cpp").takeIf { it.isFile }
    }?.sortedBy { it.path } ?: emptyList()
}

tasks.register<Exec>("setupFlutterLlamaAndroid") {
    group = "setup"
    description = "Patches flutter_llama llama.cpp headers for Android NDK builds."

    onlyIf { setupFlutterLlamaPython.exists() }

    inputs.file(setupFlutterLlamaPython)
    inputs.file(setupFlutterLlamaScript).optional(true)
    inputs.file(pubspecLock).withPathSensitivity(PathSensitivity.RELATIVE)
    outputs.file(setupFlutterLlamaStamp)

    workingDir = projectRoot

    doFirst {
        commandLine(pythonExecCommand(setupFlutterLlamaPython))
    }

    doLast {
        setupFlutterLlamaStamp.get().asFile.apply {
            parentFile.mkdirs()
            writeText("ok\n")
        }
    }
}

tasks.register<Exec>("patchWhisperKitAndroid") {
    group = "setup"
    description = "Patches whisper_kit native sources for Android null-safety."

    onlyIf { patchWhisperKitAndroidScript.exists() }

    val pubCacheDir = pubCacheDirectory()

    inputs.file(patchWhisperKitAndroidScript)
    inputs.file(pubspecLock).withPathSensitivity(PathSensitivity.RELATIVE)
    inputs.property("pubCache", pubCacheDir.absolutePath)
    inputs.files(providers.provider { whisperKitMainCppSources(pubCacheDir) })
        .optional()
        .withPropertyName("whisperKitMainCppSources")
        .withPathSensitivity(PathSensitivity.ABSOLUTE)
    outputs.file(patchWhisperKitAndroidStamp)

    workingDir = projectRoot

    doFirst {
        commandLine("bash", patchWhisperKitAndroidScript.absolutePath)
    }

    doLast {
        patchWhisperKitAndroidStamp.get().asFile.apply {
            parentFile.mkdirs()
            writeText("ok\n")
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    plugins.withId("com.android.library") {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
            ndkVersion = "29.0.13113456"
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")

    plugins.withId("com.android.application") {
        tasks.named("preBuild") {
            dependsOn(
                rootProject.tasks.named("setupFlutterLlamaAndroid"),
                rootProject.tasks.named("patchWhisperKitAndroid"),
            )
        }
    }
    plugins.withId("com.android.library") {
        tasks.named("preBuild") {
            dependsOn(
                rootProject.tasks.named("setupFlutterLlamaAndroid"),
                rootProject.tasks.named("patchWhisperKitAndroid"),
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
