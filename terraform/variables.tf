variable location {
    default="centralus"
}
variable prefix {
    default="mftfdns"
    validation {
        condition     = length(var.prefix) <= 7 
        error_message = "The prefix must be 7 characters or less."
    }
}
variable dns_username {
    default="AzureAdmin"
}



