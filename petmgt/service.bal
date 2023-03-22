import ballerina/http;
import ballerina/io;
import ballerina/lang.runtime;
import ballerina/task;

// Creates a job to be executed by the scheduler.
class Job {

    *task:Job;
    int i = 1;

    // Executes this function when the scheduled trigger fires.
    public function execute() {
        self.i += 1;
        io:println("MyCounter: ", self.i);
    }

    isolated function init(int i) {
        self.i = i;
    }
}


service / on new http:Listener(9090) {

    # A resource for generating greetings
    # + name - the input string name
    # + return - string name with hello message or error
    resource function get greeting(string name) returns string|error {
        // Send a response back to the caller.
        if name is "" {
            return error("name should not be empty!");
        }
        return "Hello, " + name;
    }
}


// Define your main function
public function main() {
    io:println("Starting the service...");

    do {
	
	    task:JobId id = check task:scheduleJobRecurByFrequency(new Job(0), 1);
        runtime:sleep(9);
        check task:unscheduleJob(id);
    } on fail var e {
    	io:println("Starting the service...",e);
    }

    io:println("stopping the service...");
}


