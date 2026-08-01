plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureAndroid: Project.() -> Unit = {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        android?.apply {
            compileSdkVersion(36)
            if ((defaultConfig.minSdkVersion?.apiLevel ?: 0) < 28) {
                defaultConfig.minSdkVersion(28)
            }
        }
    }

    if (state.executed) {
        configureAndroid()
    } else {
        afterEvaluate {
            configureAndroid()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

