allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val setupFlutterLlamaScript = rootProject.file("../tool/setup_flutter_llama_android.sh")
if (setupFlutterLlamaScript.exists()) {
    providers.exec {
        commandLine("bash", setupFlutterLlamaScript.absolutePath)
        workingDir = rootProject.file("..")
    }.result.get()
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
