import ballerina/http;

# A service representing a network-accessible API
# bound to port `9090`.
// @display {
// 	label: "pet-management-service",
// 	id: "pet-management-service-8b669441-c466-40aa-bed1-2dbc62531db7"
// }
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
