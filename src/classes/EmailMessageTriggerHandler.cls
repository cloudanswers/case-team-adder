public with sharing class EmailMessageTriggerHandler {
    
    private static final ROLE_NAME = 'Collaborator';

    private static Set<String> splitEmailList (String s) {
        Set<String> emails = new Set<String>();
        if (String.isNotBlank(s)) {
            for (String email : s.split(';')) {
                emails.add(s.trim().toLowerCase());
            }
        }
        return emails;
    }
    
    public static void createCaseTeamMember(List<EmailMessage> newEmailMessageList){
        Map<Id, Set<String>> mapCaseIdWithAddresses = new Map<Id, Set<String>>();
        Set<String> foundEmailAddresses = new Set<String>();
        for(EmailMessage  emailMsg : newEmailMessageList){
            if (emailMsg.ParentId == null || emailMsg.ParentId.getSObjectType() != Schema.Case.SObjectType) continue;
            Set<String> emailsFound = splitEmailList(emailMsg.ToAddresses);
            emailsFound.addAll(splitEmailList(emailMsg.CcAddresses));
            emailsFound.addAll(splitEmailList(emailMsg.BccAddresses));
            if (emailsFound.isEmpty()) continue;
            if(!mapCaseIdWithAddresses.containsKey(emailMsg.ParentId)){
                mapCaseIdWithAddresses.put(emailMsg.ParentId, new Set<String>());
            }
            mapCaseIdWithAddresses.get(emailMsg.ParentId).addAll(emailsFound);
            foundEmailAddresses.addAll(emailMsg.CcAddress.toLowerCase().split('; '));
        }
        
        Map<String, Id> emailToUserId = new Map<String, Id>();
        for(User u : [SELECT ID, Email, Profile.UserLicense.Name FROM USER WHERE isActive = true AND Email IN: foundEmailAddresses AND Profile.UserLicense.Name = 'Salesforce' LIMIT 10000]){
            emailToUserId.put(u.Email.toLowerCase().trim(), u.Id);
        }

        List<CaseTeamRole> caseTeamRoleList = [SELECT Id FROM CaseTeamRole WHERE Name = :ROLE_NAME LIMIT 1];
        
        // FIXME fail over to first team role if we couldn't find our normal one, smells weird, but ok for now
        if (caseTeamRoleList.isEmpty()) caseTeamRoleList = [SELECT Id FROM CaseTeamRole LIMIT 1];

        List<CaseTeamMember> caseTeamMemberList = new List<CaseTeamMember>();

        Map<Id, Set<String>> existingCaseTeamMembers = new Map<Id, Set<String>>();
        for (Case c : [
            select Id, (select Id, MemberId, Member.Email from TeamMembers)
            from Case
            where Id in :mapCaseIdWithAddresses.keySet()
        ]) {
            Set<String> emails = new Set<String>();
            for (CaseTeamMember ctm : c.TeamMembers) emails.add(ctm.Member.Email.toLowerCase().trim());
            existingCaseTeamMembers.put(c.Id, emails);
        }

        List<CaseTeamMember> toInsert = new List<CaseTeamMember>();
        for(Id caseId : mapCaseIdWithAddresses.keySet()){
            Set<String> emails = new Set<String>();
            emails = emails.removeAll(existingCaseTeamMembers.get(caseId));
            emails = emails.retainAll(emailToUserId.keySet());
            for(String email : emails){
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