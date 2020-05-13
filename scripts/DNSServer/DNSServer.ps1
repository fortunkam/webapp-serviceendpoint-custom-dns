Configuration DNSServer {
    
    Node localhost {

        WindowsFeature DnsServer {
            Ensure = 'Present'
            Name = 'DNS'
        }

        WindowsFeature DnsManagementTools {
            Ensure = 'Present'
            Name = 'RSAT-DNS-Server'
        }
    }
}