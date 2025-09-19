classdef CaseRequest
    %CASEREQUEST Represents a single scheduling demand to be processed.

    properties (SetAccess = immutable)
        CaseId string
        Date datetime
        Procedure eprefactor.Procedure
        Operator eprefactor.Operator
        AdmissionStatus string
        Location string
        Room string
        Lab eprefactor.Lab
    end

    methods
        function obj = CaseRequest(row, procedure, operator, lab)
            arguments
                row table
                procedure (1,1) eprefactor.Procedure
                operator (1,1) eprefactor.Operator
                lab eprefactor.Lab = eprefactor.Lab.empty
            end

            obj.CaseId = string(row.case_id(1));
            dateValue = row.date(1);
            if isdatetime(dateValue)
                obj.Date = dateValue;
            elseif isnumeric(dateValue)
                obj.Date = datetime(dateValue, 'ConvertFrom', 'datenum');
            else
                obj.Date = datetime(string(dateValue));
            end
            obj.Procedure = procedure;
            obj.Operator = operator;
            obj.AdmissionStatus = string(row.admission_status(1));
            obj.Location = string(row.location(1));
            obj.Room = string(row.room(1));
            obj.Lab = lab;
        end
    end
end
