public with sharing class EmailMessageTriggerHandler {
    
    private static final String ROLE_NAME = 'Collaborator';
	
    @TestVisible
    private static Set<String> splitEmailList (String s) {
        Set<String> emails = new Set<String>();
        if (String.isNotBlank(s)) {
            for (String email : s.split(';')) {
                emails.add(email.trim().toLowerCase());
            }
        }
        return emails;
    }
    
    @TestVisible
    private static Map<Id, Set<String>> getEmailsByParentId (List<EmailMessage> messages) {
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();
        for (EmailMessage emailMsg : messages) {
            System.debug(emailMsg);
            if (emailMsg.ParentId == null) continue;
            // this was not succeeding consistently during unit testing:
            // if (emailMsg.ParentId.getSObjectType() != Schema.Case.SObjectType) System.assert(false);
            if (!String.valueOf(emailMsg.ParentId).startsWith('500')) continue;
            Set<String> emailsFound = splitEmailList(emailMsg.ToAddress);
            emailsFound.addAll(splitEmailList(emailMsg.CcAddress));
            emailsFound.addAll(splitEmailList(emailMsg.BccAddress));
            if (emailsFound.isEmpty()) continue;
            if(!result.containsKey(emailMsg.ParentId)){
                result.put(emailMsg.ParentId, new Set<String>());
            }
            result.get(emailMsg.ParentId).addAll(emailsFound);
        }
        return result;
    }
    
    public static void createCaseTeamMember(List<EmailMessage> newEmailMessageList){
        Map<Id, Set<String>> mapCaseIdWithAddresses = getEmailsByParentId(newEmailMessageList);
        System.debug('mapCaseIdWithAddresses: ' + mapCaseIdWithAddresses);
        Set<String> foundEmailAddresses = new Set<String>();
        for (Set<String> s : mapCaseIdWithAddresses.values()) foundEmailAddresses.addAll(s);
        System.debug('foundEmailAddresses: ' + foundEmailAddresses);
        
        Map<Id, String> userIdToEmail = new Map<Id, String>();
        Map<String, Id> emailToUserId = new Map<String, Id>();
        for(User u : [
            SELECT Id, Email
            FROM User 
            WHERE IsActive = true 
            AND Email IN :foundEmailAddresses 
            AND Profile.UserLicense.Name = 'Salesforce' 
            LIMIT 10000
        ]){
            String email = u.Email.toLowerCase().trim();
            emailToUserId.put(email, u.Id);
            userIdToEmail.put(u.Id, email);
        }
        System.debug('emailToUserId: ' + emailToUserId);
		
        List<CaseTeamRole> caseTeamRoleList = [SELECT Id FROM CaseTeamRole WHERE Name = :ROLE_NAME LIMIT 1];
        
        // FIXME fail over to first team role if we couldn't find our normal one, smells weird, but ok for now
        if (caseTeamRoleList.isEmpty()) caseTeamRoleList = [SELECT Id FROM CaseTeamRole LIMIT 1];

        // if no roles defined in org, exit early
        if (caseTeamRoleList.isEmpty()) return;
		
        // remove addresses already on case teams
        for (CaseTeamMember ctm : [select ParentId, MemberId, Member.Email from CaseTeamMember where ParentId in :mapCaseIdWithAddresses.keySet()]) {
			String email = ctm.Member.Email;
            // weirdly, this is sometimes null when multiple emails are sent in a single transaction
            if(String.isBlank(email)) {
                email = userIdToEmail.get(ctm.MemberId);
            }
            System.assert(String.isNotBlank(email), 'email was blank, this should never happen: ' + ctm);
            System.debug('  removing existing team member: ' + email);
            mapCaseIdWithAddresses.get(ctm.ParentId).remove(email.trim().toLowerCase());
        }
        
        List<CaseTeamMember> toInsert = new List<CaseTeamMember>();
        for(Id caseId : mapCaseIdWithAddresses.keySet()){
            Set<String> emails = mapCaseIdWithAddresses.get(caseId);
            // remove non-user emails
            emails.retainAll(emailToUserId.keySet());
            
            for(String email : emails){
                Id userId = emailToUserId.get(email);
                
                toInsert.add(
                    new CaseTeamMember(
                        ParentId = caseId,
                        MemberId= emailToUserId.get(email.toLowerCase()),
                        TeamRoleId = caseTeamRoleList[0].id
                    )
                );
            }
        }
        insert toInsert;       
    }
}