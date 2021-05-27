trigger EmailMessageTrigger on EmailMessage (after insert) {
    if(Trigger.isInsert && Trigger.isAfter){
        try{
            EmailMessageTriggerHandler.createCaseTeamMember(Trigger.new);
        }catch(exception e){
            System.debug('Exception Occured ::::'+e.getStackTraceString());
        }
        
    }
}