#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <dirent.h>

#define MAX_CMD_LEN 100  // Maximum length of a command
#define HISTORY_COUNT 100  // Maximum number of commands to keep in history

char *history[HISTORY_COUNT];  // Array to store the history of commands
int history_count = 0;  // Counter for the number of commands in history

// Function to add a command to the history
void add_to_history(char *cmd) {
     // If history is not full
    if (history_count < HISTORY_COUNT) {
      // Add command to history
        history[history_count++] = strdup(cmd);
    } else {  // If history is full
      // Free the memory of the oldest command
        free(history[0]);

        // Shift the remaining commands up in the history array
        memmove(&history[0], &history[1], sizeof(char *) * (HISTORY_COUNT - 1));

        // Add new command at the end
        history[HISTORY_COUNT - 1] = strdup(cmd);
    }
}

// Function to print the history of commands
void print_history() {
      // Loop through all commands in history
    for (int i = 0; i < history_count; i++) {
          // Print each command with its number
        printf("%s\n", history[i]);
    }
}

// Function to change the current directory to the specified path
void change_directory(char *path) {
      // Attempt to change directory
    if (chdir(path) != 0) {
        perror("chdir failed");
    }
}

// Function to print the current working directory
void print_working_directory() {
  // Buffer to store the current working directory
    char cwd[4096];
    if (getcwd(cwd, sizeof(cwd)) != NULL) {
          // Print the current working directory
        printf("%s\n", cwd);
    } else {  // If getcwd fails
        perror("getcwd failed");
    }
}


// Function to execute a command
void execute_cmd(char *cmd) {
      // Fork a new process
    int pid = fork();

    // If fork fails
    if (pid < 0) {
        perror("fork failed");
        return;
    }

    if (pid == 0) {  // In the child process
        // Array to store the command and its arguments
        char *args[MAX_CMD_LEN] = {NULL};
        char *token = strtok(cmd, " ");  // Tokenize the command
        int i = 0;

        while (token != NULL) {  // While there are tokens
            // Add the token to args
            args[i++] = token; 
             // Get the next token
            token = strtok(NULL, " ");
        }        

        // Execute the command
        execvp(args[0], args);
        fprintf(stderr, "%s: ", args[0]);
        perror("failed");
        exit(1);
    } else {  // In the parent process
        wait(NULL);  // Wait for the child process to finish
    }
}



int main(int argc, char *argv[]) {
    // Save the original PATH
    char *original_path = strdup(getenv("PATH"));

    // Loop over each command-line argument
    for (int i = 1; i < argc; i++) {
        // Get the current PATH
        char *path = getenv("PATH");

        // Allocate memory for the new PATH
        char *new_path = malloc(strlen(path) + strlen(argv[i]) + 2);  // +2 for the colon and the null terminator

        // Construct the new PATH
        strcpy(new_path, path);
        strcat(new_path, ":");
        strcat(new_path, argv[i]);

        // Set the new PATH
        setenv("PATH", new_path, 1);

        // Free the allocated memory
        free(new_path);
    }

    char cmd[MAX_CMD_LEN]; // Buffer to store the command

    while (1) {  // Infinite loop
        // Print the terminal prompt
        printf("$ ");
        // Flush the output buffer
        fflush(stdout);
        // Read a command
        if (fgets(cmd, sizeof(cmd), stdin) == NULL) {
            break;  // Break the loop if fgets fails
        }

        // If the last character is a newline replace it with a null character
        if (cmd[strlen(cmd) - 1] == '\n') {  
            cmd[strlen(cmd) - 1] = '\0';
        }

        // Add the command to history
        add_to_history(cmd);

        // Execute the command based on its type
        if (strcmp(cmd, "history") == 0) {
            print_history();
        } else if (strncmp(cmd, "cd ", 3) == 0) {
            change_directory(cmd + 3);
        } else if (strcmp(cmd, "pwd") == 0) {
            print_working_directory();
        } else if (strcmp(cmd, "exit") == 0) {
            // Restore the original PATH before exiting
            setenv("PATH", original_path, 1);
            free(original_path);
            break;
        } else {
            execute_cmd(cmd);
        }
    }
    return 0;  // Return 0 to indicate successful execution
}
