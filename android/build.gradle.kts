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
val pubspecLock = projectRoot.resolve("pubspec.lock")
val setupFlutterLlamaStamp =
    rootProject.layout.buildDirectory.file("setup_flutter_llama_android.stamp")

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
            )
        }
    }
    plugins.withId("com.android.library") {
        tasks.named("preBuild") {
            dependsOn(
                rootProject.tasks.named("setupFlutterLlamaAndroid"),
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
