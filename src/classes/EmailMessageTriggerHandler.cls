/**
 * @description trigger handler for EmailMessage to automatically associate case team members when the cc'd field has a user's email
 */
public with sharing class EmailMessageTriggerHandler {
    
    // FIXME move to setting
    private static final String ROLE_NAME = 'Collaborator';

    @TestVisible
    /**
     * @description splitEmailList description
     * @param  s list of emails from the email message, separated by semicolon
     * @return   return description
     */
    private static Set<String> splitEmailList (String s) {
        Set<String> emails = new Set<String>();
        if (String.isNotBlank(s)) {
            for (String email : s.split(';')) {
                emails.add(email.trim().toLowerCase());
            }
        }
        return emails;
    }
    
    /**
     * @description creates a map of email messages to their related email addresses
     * @param  messages messages description
     * @return finds the unique email addresses for each email (ParentId)
     */
    @TestVisible
    private static Map<Id, Set<String>> getEmailsByParentId (List<EmailMessage> messages) {
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();
        for (EmailMessage emailMsg : messages) {
            System.debug(System.LoggingLevel.DEBUG, emailMsg);
            if (emailMsg.ParentId == null) {
                continue;
            }
            // this was not succeeding consistently during unit testing:
            // if (emailMsg.ParentId.getSObjectType() != Schema.Case.SObjectType) System.assert(false);
            if (!String.valueOf(emailMsg.ParentId).startsWith('500')) {
                continue;
            }
            Set<String> emailsFound = splitEmailList(emailMsg.ToAddress);
            emailsFound.addAll(splitEmailList(emailMsg.CcAddress));
            emailsFound.addAll(splitEmailList(emailMsg.BccAddress));
            if (emailsFound.isEmpty()) {
                continue;
            }
            if(!result.containsKey(emailMsg.ParentId)){
                result.put(emailMsg.ParentId, new Set<String>());
            }
            result.get(emailMsg.ParentId).addAll(emailsFound);
        }
        return result;
    }
    
    /**
     * @description entrypoint for the triggerhandler
     * @param  newEmailMessageList list of EmailMessage records from the EmailMessage trigger
     */
    public static void createCaseTeamMember(List<EmailMessage> newEmailMessageList){
        Map<Id, Set<String>> mapCaseIdWithAddresses = getEmailsByParentId(newEmailMessageList);
        System.debug(System.LoggingLevel.DEBUG, 'mapCaseIdWithAddresses: ' + mapCaseIdWithAddresses);
        Set<String> foundEmailAddresses = new Set<String>();
        for (Set<String> s : mapCaseIdWithAddresses.values()) {
            foundEmailAddresses.addAll(s);
        }
        System.debug(System.LoggingLevel.DEBUG, 'foundEmailAddresses: ' + foundEmailAddresses);
        
        Map<Id, String> userIdToEmail = new Map<Id, String>();
        Map<String, Id> emailToUserId = new Map<String, Id>();
        
        // FIXME this will be a disaster in large orgs
        for(User u : [
            SELECT Id, Email
            FROM User 
            WHERE IsActive = true 
            AND Email IN :foundEmailAddresses 
            AND Profile.UserLicense.Name = 'Salesforce' 
            WITH SECURITY_ENFORCED
            ORDER BY LastModifiedDate desc
            LIMIT 1000
        ]){
            String email = u.Email.toLowerCase().trim();
            emailToUserId.put(email, u.Id);
            userIdToEmail.put(u.Id, email);
        }
        System.debug(System.LoggingLevel.DEBUG, 'emailToUserId: ' + emailToUserId);
		
        List<CaseTeamRole> caseTeamRoleList = [SELECT Id FROM CaseTeamRole WHERE Name = :ROLE_NAME WITH SECURITY_ENFORCED LIMIT 1];
        
        // fail over to first team role if we couldn't find our desired one
        if (caseTeamRoleList.isEmpty()) {
            caseTeamRoleList = [SELECT Id FROM CaseTeamRole WITH SECURITY_ENFORCED LIMIT 1];
        }

        if (caseTeamRoleList.isEmpty()) {
            System.debug(System.LoggingLevel.WARNING, 'no case team roles configured in this org');
            return;
        }
		
        // remove addresses already on case teams
        for (CaseTeamMember ctm : [select ParentId, MemberId, Member.Email from CaseTeamMember where ParentId in :mapCaseIdWithAddresses.keySet()]) {
			
            // weirdly, this is sometimes null when multiple emails are sent in a single transaction
            // maybe a platform bug?
            String email = ctm.Member.Email;
            if(String.isBlank(email)) {
                System.debug(System.LoggingLevel.WARNING, '  email field is null on member object, looking up from user table: ' + ctm);
                email = userIdToEmail.get(ctm.MemberId);
            }
            System.assert(String.isNotBlank(email), 'email was blank, this should never happen: ' + ctm);
            System.debug(System.LoggingLevel.DEBUG, '  removing existing team member: ' + email);
            mapCaseIdWithAddresses.get(ctm.ParentId).remove(email.trim().toLowerCase());
        }
        
        List<CaseTeamMember> toInsert = new List<CaseTeamMember>();
        for(Id caseId : mapCaseIdWithAddresses.keySet()){
            Set<String> emails = mapCaseIdWithAddresses.get(caseId);
            
            // remove non-user emails
            emails.retainAll(emailToUserId.keySet());
            
            for(String email : emails){
                toInsert.add(
                    new CaseTeamMember(
                        ParentId = caseId,
                        MemberId = emailToUserId.get(email.toLowerCase()),
                        TeamRoleId = caseTeamRoleList[0].id
                    )
                );
            }
        }
        if (!Schema.sObjectType.CaseTeamMember.isCreateable()) {
            System.debug(System.LoggingLevel.ERROR, 'CaseTeamMember not creatable');
        } else {
            // insert without allOrNone so we don't block email insertion on error
            Database.insert(toInsert, false);
        }
    }
}