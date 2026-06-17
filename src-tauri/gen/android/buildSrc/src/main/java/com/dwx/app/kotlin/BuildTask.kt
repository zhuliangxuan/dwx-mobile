package com.dwx.app

import java.io.File
import org.apache.tools.ant.taskdefs.condition.Os
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.logging.LogLevel
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.TaskAction

open class BuildTask : DefaultTask() {
    @Input
    var rootDirRel: String? = null
    @Input
    var target: String? = null
    @Input
    var release: Boolean? = null

    @TaskAction
    fun assemble() {
        val target = target ?: throw GradleException("target cannot be null")
        val release = release ?: throw GradleException("release cannot be null")

        val skipBuild = System.getenv("TAURI_SKIP_RUST_BUILD")
        if (skipBuild != null && skipBuild.equals("true", ignoreCase = true)) {
            project.logger.lifecycle("Skipping rust build for target $target (release=$release) - .so files already copied manually")
            return
        }

        val rootDir = File(project.projectDir, rootDirRel ?: ".").absoluteFile
        val releaseFlag = if (release) "--release" else ""

        val command: List<String> = if (Os.isFamily(Os.FAMILY_WINDOWS)) {
            listOf("powershell", "-Command", "cd ${rootDir.absolutePath}; cargo build --target $target $releaseFlag")
        } else {
            listOf("bash", "-c", "cd ${rootDir.absolutePath} && cargo build --target $target $releaseFlag")
        }

        project.logger.lifecycle("Building rust for target $target (release=$release) with command: ${command.joinToString(" ")}")

        val processBuilder = ProcessBuilder(command)
            .directory(rootDir)
            .redirectErrorStream(true)

        val process = processBuilder.start()
        val output = process.inputStream.bufferedReader().readText()
        val exitCode = process.waitFor()

        if (exitCode != 0) {
            project.logger.error("Rust build failed with exit code $exitCode")
            project.logger.error(output)
            throw GradleException("Failed to build rust for target $target")
        }

        project.logger.lifecycle("Rust build completed for target $target")
    }
}
