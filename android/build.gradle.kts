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
    if (project.name != "app") {
        val configureSdk = {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val getCompileSdk = android.javaClass.methods.firstOrNull {
                        (it.name == "getCompileSdkVersion" || it.name == "getCompileSdk") &&
                            it.parameterTypes.isEmpty()
                    }
                    val currentSdk = getCompileSdk?.invoke(android)
                    val sdkVersionNum = when (currentSdk) {
                        is Number -> currentSdk.toInt()
                        is String -> currentSdk.replace("android-", "").toIntOrNull() ?: 0
                        else -> 0
                    }
                    if (sdkVersionNum in 1..35) {
                        val setMethod = android.javaClass.methods.firstOrNull {
                            (it.name == "setCompileSdkVersion" || it.name == "compileSdkVersion" || it.name == "setCompileSdk") &&
                                it.parameterTypes.size == 1 &&
                                (it.parameterTypes[0] == Int::class.javaPrimitiveType || it.parameterTypes[0] == java.lang.Integer::class.java)
                        }
                        setMethod?.invoke(android, 36)
                    }
                } catch (_: Exception) {
                }
            }
        }

        if (project.state.executed) {
            configureSdk()
        } else {
            project.afterEvaluate {
                configureSdk()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
