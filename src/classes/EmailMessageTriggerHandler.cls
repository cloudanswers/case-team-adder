public with sharing class EmailMessageTriggerHandler {
    
    public static void createCaseTeamMember(List<EmailMessage> newEmailMessageList){
        Map<Id, Set<String>> mapCaseIdWithCCAddresses = new Map<Id, Set<String>>();
        Set<String> ccAddresses = new Set<String>();
        for(EmailMessage  emailMsg : newEmailMessageList){
            if(emailMsg.Incoming && emailMsg.CcAddress != null  && emailMsg.ParentId != null && String.valueOf(emailMsg.ParentId).substring(0,3) == '500'){
                if(!mapCaseIdWithCCAddresses.containsKey(emailMsg.ParentId)){
                    mapCaseIdWithCCAddresses.put(emailMsg.ParentId, new Set<String>());
                }
                mapCaseIdWithCCAddresses.get(emailMsg.ParentId).addAll(emailMsg.CcAddress.split('; '));
                ccAddresses.addAll(emailMsg.CcAddress.toLowerCase().split('; '));
            }
        }
        
        System.debug('ccAddresses:::'+ccAddresses);
        
        Map<String, Id> mapEmailWithUserId = new Map<String, Id>();
        for(User userRec : [SELECT ID, Email, Profile.UserLicense.Name FROM USER WHERE isActive = true AND Email IN: ccAddresses AND Profile.UserLicense.Name = 'Salesforce' LIMIT 10000]){
            mapEmailWithUserId.put(userRec.Email.toLowerCase(),userRec.Id);
        }
        
        
        List<CaseTeamRole> caseTeamRoleList = [SELECT Id FROM CaseTeamRole WHERE Name = 'Managing Role' LIMIT 1];
       
        List<CaseTeamMember> caseTeamMemberList = new List<CaseTeamMember>();
       
        if(caseTeamRoleList.size()>0){
            for(Id caseId : mapCaseIdWithCCAddresses.keySet()){
                for(String email : mapCaseIdWithCCAddresses.get(caseId)){
                    if(mapEmailWithUserId.containsKey(email.toLowerCase())){
                         System.debug('userRec.Id::'+email.toLowerCase());
                        System.debug('userRec.Id::'+mapEmailWithUserId.get(email.toLowerCase()));
                        CaseTeamMember caseTeamMemberRec =new CaseTeamMember();
                        caseTeamMemberRec.ParentId= caseId;
                        caseTeamMemberRec.MemberId= mapEmailWithUserId.get(email.toLowerCase());
                        caseTeamMemberRec.TeamRoleId = caseTeamRoleList[0].id;
                        caseTeamMemberList.add(caseTeamMemberRec);
                    }
                }
            }
        }
        
        
      Database.saveResult[] saveResultList = Database.insert(caseTeamMemberList,false);
        for(Database.saveResult saveResult : saveResultList){
            if(!saveResult.isSuccess()){
                for(Database.Error error : saveResult.getErrors()){
                    System.debug('Error Occured:::'+error.getMessage()+' :: '+error.getStatusCode()+' :: '+error.getFields() );
                }
            }
        }
       
    }
    
    
}